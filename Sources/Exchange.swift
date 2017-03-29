//
//  Exchange.swift
//  Impeller
//
//  Created by Drew McCormack on 11/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

import Foundation


public protocol Cursor {
    var data: Data { get }
}


public protocol Exchangable: class {
    
    var uniqueIdentifier: UniqueIdentifier { get }
    
    func push(changesSince cursor: Cursor?, completionHandler completion: @escaping (Error?, [ValueTree], Cursor?)->Void)
    func pull(_ ValueTrees: [ValueTree], completionHandler completion: @escaping CompletionHandler)
    
    func makeCursor(fromData data: Data) -> Cursor?
}


public class Exchange {
    public let exchangables: [Exchangable]
    public let pathForSavedState: String?
    private let queue = DispatchQueue(label: "impeller.exchange")
    private var cursorsByExchangableIdentifier: [UniqueIdentifier:Cursor]
    
    public init(coupling exchangables: [Exchangable], pathForSavedState: String?) {
        precondition(exchangables.count > 1)
        self.exchangables = exchangables
        self.pathForSavedState = pathForSavedState
        cursorsByExchangableIdentifier = [UniqueIdentifier:Cursor]()
    }
    
    func cursor(forExchangableIdentifiedBy identifier: UniqueIdentifier) -> Cursor? {
        return cursorsByExchangableIdentifier[identifier]
    }
    
    func commit(_ cursor: Cursor?, forExchangableIdentifiedBy identifier: UniqueIdentifier) {
        cursorsByExchangableIdentifier[identifier] = cursor
    }
    
    public func exchange(completionHandler completion:CompletionHandler?) {
        var returnError: Error?
        let group = DispatchGroup()
        
        for e1 in exchangables {
            let uniqueIdentifier = e1.uniqueIdentifier
            let c1 = cursor(forExchangableIdentifiedBy: uniqueIdentifier)

            group.enter()
            queue.async {
                e1.push(changesSince: c1) {
                    error, dictionaries, newCursor in
                    
                    defer {
                        self.queue.async {
                            defer { group.leave() }
                            guard returnError == nil else { return }
                            self.commit(newCursor, forExchangableIdentifiedBy: uniqueIdentifier)
                        }
                    }
                    
                    guard returnError == nil else { return }
                    guard error == nil else { returnError = error; return }
                    
                    for e2 in self.exchangables {
                        guard e1 !== e2 else { continue }
                        group.enter()
                        self.queue.async {
                            e2.pull(dictionaries) {
                                error in
                                defer { group.leave() }
                                guard returnError == nil else { return }
                                guard error == nil else { returnError = error; return }
                            }
                        }
                    }
                }
            }
        }
        
        group.notify(queue: DispatchQueue.main) {
            completion?(returnError)
        }
    }
    
    func save() {
        guard let pathForSavedState = pathForSavedState else { return }
        let cursorDataByIdentifier = cursorsByExchangableIdentifier.mapValues { $1.data } as NSDictionary
        cursorDataByIdentifier.write(toFile: pathForSavedState, atomically: true)
    }
    
    func load() {
        guard let pathForSavedState = pathForSavedState else { return }
        guard let cursorDataByIdentifier = NSDictionary(contentsOfFile: pathForSavedState) as? [String:Data] else { return }
        
        var newCursors = [UniqueIdentifier:Cursor]()
        for (id, data) in cursorDataByIdentifier {
            if  let exchangable = exchangables.filter({ $0.uniqueIdentifier == id }).first,
                let cursor = exchangable.makeCursor(fromData: data) {
                newCursors[id] = cursor
            }
        }
        
        cursorsByExchangableIdentifier = newCursors
    }
}

