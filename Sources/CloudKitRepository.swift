//
//  CloudKitRepository.swift
//  Impeller
//
//  Created by Drew McCormack on 29/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Foundation
import CloudKit


public struct CloudKitCursor: Cursor {
    var serverToken: CKServerChangeToken
    
    init(serverToken: CKServerChangeToken) {
        self.serverToken = serverToken
    }
    
    init?(data: Data) {
        if let newToken = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken {
            serverToken = newToken
        }
        else {
            return nil
        }
    }
    
    public var data: Data {
        return NSKeyedArchiver.archivedData(withRootObject: serverToken)
    }
}


@available (macOS 10.12, iOS 10, *)
public class CloudKitRepository: Exchangable {
    
    public let uniqueIdentifier: UniqueIdentifier
    private let database: CKDatabase
    private let zone: CKRecordZone
    private let prepareZoneOperation: CKDatabaseOperation
    
    public init(withUniqueIdentifier identifier: UniqueIdentifier, cloudDatabase: CKDatabase) {
        self.uniqueIdentifier = identifier
        self.database = cloudDatabase
        self.zone = CKRecordZone(zoneName: uniqueIdentifier)
        self.prepareZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [self.zone], recordZoneIDsToDelete: nil)
        self.database.add(self.prepareZoneOperation)
    }
    
    public func removeZone(completionHandler completion:@escaping CompletionHandler) {
        database.delete(withRecordZoneID: zone.zoneID) { zoneID, error in
            completion(error)
        }
    }

    public func push(changesSince cursor: Cursor?, completionHandler completion: @escaping (Error?, [ValueTree], Cursor?)->Void) {
        var newCursor: CloudKitCursor?
        var valueTrees = [ValueTree]()
        
        let token = (cursor as? CloudKitCursor)?.serverToken
        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = token
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone.zoneID], optionsByRecordZoneID: [zone.zoneID : options])
        operation.addDependency(prepareZoneOperation)
        operation.fetchAllChanges = true
        operation.recordChangedBlock = { record in
            if let valueTree = record.asValueTree {
                valueTrees.append(valueTree)
            }
        }
        operation.recordWithIDWasDeletedBlock = { recordID in
            // TODO: Finish implementing deletions
        }
        operation.recordZoneFetchCompletionBlock = { zoneID, token, clientData, moreComing, error in
            if let token = token, error == nil {
                newCursor = CloudKitCursor(serverToken: token)
            }
        }
        operation.fetchRecordZoneChangesCompletionBlock = { error in
            if let error = error as? CKError {
                if error.code == .changeTokenExpired {
                    completion(nil, [], nil)
                }
                else {
                    completion(error, [], nil)
                }
            }
            else {
                completion(nil, valueTrees, newCursor)
            }
        }
        
        database.add(operation)
    }
    
    public func pull(_ valueTrees: [ValueTree], completionHandler completion: @escaping CompletionHandler) {
        let valueTreesByRecordID = valueTrees.elementsByKey { $0.recordID(inZoneWithID: zone.zoneID) }
        let recordIDs = Array(valueTreesByRecordID.keys)
        let fetchOperation = CKFetchRecordsOperation(recordIDs: recordIDs)
        fetchOperation.addDependency(prepareZoneOperation)
        fetchOperation.fetchRecordsCompletionBlock = { recordsByRecordID, error in
            // Only acceptable errors are partial errors where code is .unknownItem
            let ckError = error as! CKError?
            guard ckError == nil || ckError!.code == .partialFailure else {
                completion(error)
                return
            }
            for (_, partialError) in ckError?.partialErrorsByItemID ?? [:] {
                guard (partialError as! CKError).code == .unknownItem else {
                    completion(error)
                    return
                }
            }
        
            // Process updates
            var recordsToUpload = [CKRecord]()
            for pulledValueTree in valueTrees {
                let recordID = pulledValueTree.recordID(inZoneWithID: self.zone.zoneID)
                let record = recordsByRecordID![recordID]
                let cloudValueTree = record?.asValueTree
                let mergedTree = pulledValueTree.merged(with: cloudValueTree)
                if mergedTree != cloudValueTree {
                    let recordToUpdate = record ?? CKRecord(recordType: pulledValueTree.repositedType, recordID: recordID)
                    mergedTree.updateRecord(recordToUpdate)
                    recordsToUpload.append(recordToUpdate)
                }
            }
            
            // Upload
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToUpload, recordIDsToDelete: nil)
            modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                completion(error)
            }
            self.database.add(modifyOperation)
        }
        
        database.add(fetchOperation)
    }
    
    public func makeCursor(fromData data: Data) -> Cursor? {
        return CloudKitCursor(data: data)
    }
}


extension ValueTree {
    
    var recordName: String {
        return "\(repositedType)__\(metadata.uniqueIdentifier)"
    }
    
    func recordID(inZoneWithID zoneID: CKRecordZoneID) -> CKRecordID {
        return CKRecordID(recordName: recordName, zoneID: zoneID)
    }
    
    func makeRecord(inZoneWithID zoneID:CKRecordZoneID) -> CKRecord {
        let recordID = self.recordID(inZoneWithID: zoneID)
        let newRecord = CKRecord(recordType: repositedType, recordID: recordID)
        updateRecord(newRecord)
        return newRecord
    }
    
    func updateRecord(_ record: CKRecord) {
        record["metadata__timestamp"] = metadata.timestamp as CKRecordValue
        record["metadata__version"] = metadata.version as CKRecordValue
        record["metadata__isDeleted"] = metadata.isDeleted as CKRecordValue
        for name in propertyNames {
            let property = get(name)!
            
            let propertyTypeKey = name + "__metadata__propertyType"
            record[propertyTypeKey] = property.propertyType.rawValue as CKRecordValue
            
            switch property {
            case .primitive(let primitive):
                let typeKey = name + "__metadata__primitiveType"
                record[typeKey] = primitive.type.rawValue as CKRecordValue
                record[name] = primitive.value as? CKRecordValue
            case .optionalPrimitive(let primitive):
                let typeKey = name + "__metadata__primitiveType"
                if let primitive = primitive {
                    record[typeKey] = primitive.type.rawValue as CKRecordValue
                    record[name] = primitive.value as? CKRecordValue
                }
                else {
                    record[typeKey] = 0 as CKRecordValue
                    record[name] = nil
                }
            case .primitives(let primitives):
                let typeKey = name + "__metadata__primitiveType"
                if primitives.count > 0 {
                    record[typeKey] = primitives.first!.type.rawValue as CKRecordValue
                    record[name] = primitives.map { $0.value } as CKRecordValue
                }
                else {
                    record[typeKey] = 0 as CKRecordValue
                    record[name] = [] as CKRecordValue
                }
            case .valueTreeReference(let ref):
                record[name] = [ref.repositedType, ref.uniqueIdentifier] as CKRecordValue
            case .optionalValueTreeReference(let ref):
                if let ref = ref {
                    record[name] = [ref.repositedType, ref.uniqueIdentifier] as CKRecordValue
                }
                else {
                    record[name] = ["nil", ""] as CKRecordValue
                }
            case .valueTreeReferences(let refs):
                record[name] = refs.map { $0.recordName } as CKRecordValue
            }
        }
    }
    
}


extension ValueTreeReference {
    
    var recordName: String {
        // Record name is repositedType + "__" + unique id. This is because in Impeller,
        // the uniqueId only has to be unique for a single stored type
        return "\(repositedType)__\(uniqueIdentifier)"
    }
    
}


extension String {

    var valueTreeReference: ValueTreeReference {
        let recordName = self
        let components = recordName.components(separatedBy: "__")
        return ValueTreeReference(uniqueIdentifier: components[1], repositedType: components[0])
    }

}


extension CKRecord {
    
    var valueTreeReference: ValueTreeReference {
        return recordID.recordName.valueTreeReference
    }
    
    var asValueTree: ValueTree? {
        guard let timestamp = self["metadata__timestamp"] as? TimeInterval,
              let version = self["metadata__version"] as? RepositedVersion,
              let isDeleted = self["metadata__isDeleted"] as? Bool else {
            return nil
        }
        
        let ref = valueTreeReference
        var metadata = Metadata(uniqueIdentifier: ref.uniqueIdentifier)
        metadata.version = version
        metadata.timestamp = timestamp
        metadata.isDeleted = isDeleted
        
        var valueTree = ValueTree(repositedType: recordType, metadata: metadata)
        for key in allKeys() {
            if key.contains("__metadata__") { continue }
            
            let propertyTypeKey = key + "__metadata__propertyType"
            guard
                let value = self[key],
                let propertyTypeInt = self[propertyTypeKey] as? Int,
                let propertyType = PropertyType(rawValue: propertyTypeInt) else {
                continue
            }
            
            let primitiveTypeKey = key + "__metadata__primitiveType"
            let primitiveTypeInt = self[primitiveTypeKey] as? Int
            let primitiveType = primitiveTypeInt != nil ? PrimitiveType(rawValue: primitiveTypeInt!) : nil
            
            var property: Property?
            switch propertyType {
            case .primitive:
                switch primitiveType! {
                case .string:
                    guard let v = value as? String else { continue }
                    property = .primitive(.string(v))
                case .int:
                    guard let v = value as? Int else { continue }
                    property = .primitive(.int(v))
                case .float:
                    guard let v = value as? Float else { continue }
                    property = .primitive(.float(v))
                case .bool:
                    guard let s = value as? Bool else { continue }
                    property = .primitive(.bool(s))
                case .data:
                    guard let s = value as? Data else { continue }
                    property = .primitive(.data(s))
                }
            case .optionalPrimitive:
                let isNull = primitiveTypeInt == 0
                if isNull {
                    property = .optionalPrimitive(nil)
                }
                else {
                    switch primitiveType! {
                    case .string:
                        guard let v = value as? String else { continue }
                        property = .optionalPrimitive(.string(v))
                    case .int:
                        guard let v = value as? Int else { continue }
                        property = .optionalPrimitive(.int(v))
                    case .float:
                        guard let v = value as? Float else { continue }
                        property = .optionalPrimitive(.float(v))
                    case .bool:
                        guard let v = value as? Bool else { continue }
                        property = .optionalPrimitive(.bool(v))
                    case .data:
                        guard let v = value as? Data else { continue }
                        property = .optionalPrimitive(.data(v))
                    }
                }
            case .primitives:
                let isEmpty = primitiveTypeInt == 0
                if isEmpty {
                    property = .primitives([])
                }
                else {
                    switch primitiveType! {
                    case .string:
                        guard let v = value as? [String] else { continue }
                        property = .primitives(v.map { .string($0) })
                    case .int:
                        guard let v = value as? [Int] else { continue }
                        property = .primitives(v.map { .int($0) })
                    case .float:
                        guard let v = value as? [Float] else { continue }
                        property = .primitives(v.map { .float($0) })
                    case .bool:
                        guard let v = value as? [Bool] else { continue }
                        property = .primitives(v.map { .bool($0) })
                    case .data:
                        guard let v = value as? [Data] else { continue }
                        property = .primitives(v.map { .data($0) })
                    }
                }
            case .valueTreeReference:
                guard let v = value as? [String], v.count == 2 else { continue }
                let ref = ValueTreeReference(uniqueIdentifier: v[1], repositedType: v[0])
                property = .valueTreeReference(ref)
            case .optionalValueTreeReference:
                guard let v = value as? [String], v.count == 2 else { continue }
                if v[0] == "nil" {
                    property = .optionalValueTreeReference(nil)
                }
                else {
                    let ref = ValueTreeReference(uniqueIdentifier: v[1], repositedType: v[0])
                    property = .optionalValueTreeReference(ref)
                }
            case .valueTreeReferences:
                guard let v = value as? [String] else { continue }
                let refs = v.map { $0.valueTreeReference }
                property = .valueTreeReferences(refs)
            }
            
            guard let p = property else {
                continue
            }
            
            valueTree.set(key, to: p)
        }
        
        return valueTree
    }
    
}

