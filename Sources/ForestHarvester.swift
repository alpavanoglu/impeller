//
//  ForestHarvester.swift
//  Impeller
//
//  Created by Drew McCormack on 15/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

/// Makes tree of repositables from a give value tree
public final class ForestHarvester {
    
    let forest: Forest
    
    public init(forest: Forest) {
        self.forest = forest
    }
    
    public func harvest<T:Repositable>(_ valueTree: ValueTree) -> T {
        let harvester = ValueTreeHarvester(valueTree: valueTree, forestHarvester: self)
        return harvester.harvest()
    }
    
    func harvestChild<T:Repositable>(_ childReference: ValueTreeReference) -> T {
        let valueTree = forest.valueTree(at: childReference)
        return harvest(valueTree!)
    }
}
