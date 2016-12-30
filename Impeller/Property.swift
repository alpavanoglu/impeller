//
//  Property.swift
//  Impeller
//
//  Created by Drew McCormack on 30/12/2016.
//  Copyright © 2016 Drew McCormack. All rights reserved.
//

public enum Property: Equatable {
    case primitive(Primitive)
    case optionalPrimitive(Primitive?)
    case primitives([Primitive])
    case valueTree(ValueTree)
    case optionalValueTree(ValueTree?)
    case valueTrees([ValueTree])
    case valueTreeReference(ValueTreeReference)
    case optionalValueTreeReference(ValueTreeReference?)
    case valueTreeReferences([ValueTreeReference])
    
    init?(type:Int16, value:Any) {
        switch type {
        case 10:
            guard let v = value as? Primitive else { return nil }
            self = .primitive(v)
        case 40:
            guard let v = value as? ValueTree else { return nil }
            self = .valueTree(v)
        case 70:
            guard let v = value as? ValueTreeReference else { return nil }
            self = .valueTreeReference(v)
        default:
            return nil
        }
    }
    
    init?(type:Int16, value:Any?) {
        switch type {
        case 20:
            guard let v = value as? Primitive? else { return nil }
            self = .optionalPrimitive(v)
        case 50:
            guard let v = value as? ValueTree? else { return nil }
            self = .optionalValueTree(v)
        case 80:
            guard let v = value as? ValueTreeReference? else { return nil }
            self = .optionalValueTreeReference(v)
        default:
            return nil
        }
    }
    
    init?(type:Int16, value:[Any]) {
        switch type {
        case 30:
            guard let v = value as? [Primitive] else { return nil }
            self = .primitives(v)
        case 60:
            guard let v = value as? [ValueTree] else { return nil }
            self = .valueTrees(v)
        case 90:
            guard let v = value as? [ValueTreeReference] else { return nil }
            self = .valueTreeReferences(v)
        default:
            return nil
        }
    }
    
    public var type: Int16 {
        switch self {
        case .primitive:
            return 10
        case .optionalPrimitive:
            return 20
        case .primitives:
            return 30
        case .valueTree:
            return 40
        case .optionalValueTree:
            return 50
        case .valueTrees:
            return 60
        case .valueTreeReference:
            return 70
        case .optionalValueTreeReference:
            return 80
        case .valueTreeReferences:
            return 90
        }
    }
    
    public var isOptional: Bool {
        switch self {
        case .primitive:
            return false
        case .optionalPrimitive:
            return true
        case .primitives:
            return false
        case .valueTree:
            return false
        case .optionalValueTree:
            return true
        case .valueTrees:
            return false
        case .valueTreeReference:
            return false
        case .optionalValueTreeReference:
            return true
        case .valueTreeReferences:
            return false
        }
    }
    
    public func asPrimitive() -> Primitive? {
        switch self {
        case .primitive(let v):
            return v
        default:
            return nil
        }
    }
    
    public func asOptionalPrimitive() -> Primitive?? {
        switch self {
        case .optionalPrimitive(let v):
            return v
        default:
            return nil
        }
    }
    
    public func asPrimitives() -> [Primitive]? {
        switch self {
        case .primitives(let v):
            return v
        default:
            return nil
        }
    }
    
    public func asValueTree() -> ValueTree? {
        switch self {
        case .valueTree(let v):
            return v
        default:
            return nil
        }
    }
    
    public func asOptionalValueTree() -> ValueTree?? {
        switch self {
        case .optionalValueTree(let v):
            return v
        default:
            return nil
        }
    }
    
    public func asValueTrees() -> [ValueTree]? {
        switch self {
        case .valueTrees(let v):
            return v
        default:
            return nil
        }
    }
    
    public func asValueTreeReference() -> ValueTreeReference? {
        switch self {
        case .valueTreeReference(let v):
            return v
        case .valueTree(let v):
            return v.valueTreeReference
        default:
            return nil
        }
    }
    
    public func asOptionalValueTreeReference() -> ValueTreeReference?? {
        switch self {
        case .optionalValueTreeReference(let v):
            return v
        case .optionalValueTree(let v):
            return v?.valueTreeReference
        default:
            return nil
        }
    }
    
    public func asValueTreeReferences() -> [ValueTreeReference]? {
        switch self {
        case .valueTreeReferences(let v):
            return v
        case .valueTrees(let v):
            return v.map { $0.valueTreeReference }
        default:
            return nil
        }
    }
    
    public func referenceTransformed() -> Property {
        switch self {
        case .valueTree(let tree):
            return .valueTreeReference(tree.valueTreeReference)
        case .optionalValueTree(let tree):
            return .optionalValueTreeReference(tree?.valueTreeReference)
        case .valueTrees(let trees):
            return .valueTreeReferences(trees.map { $0.valueTreeReference })
        case .primitive, .optionalPrimitive, .primitives, .valueTreeReference, .optionalValueTreeReference, .valueTreeReferences:
            return self
        }
    }
    
    public static func ==(left: Property, right: Property) -> Bool {
        switch (left, right) {
        case let (.primitive(l), .primitive(r)):
            return l == r
        case let (.optionalPrimitive(l), .optionalPrimitive(r)):
            return l == r
        case let (.primitives(l), .primitives(r)):
            return l == r
        case let (.valueTree(l), .valueTree(r)):
            return l == r
        case let (.optionalValueTree(l), .optionalValueTree(r)):
            return l == r
        case let (.valueTrees(l), .valueTrees(r)):
            return l == r
        case let (.valueTreeReference(l), .valueTreeReference(r)):
            return l == r
        case let (.optionalValueTreeReference(l), .optionalValueTreeReference(r)):
            return l == r
        case let (.valueTreeReferences(l), .valueTreeReferences(r)):
            return l == r
        default:
            return false
        }
    }
}