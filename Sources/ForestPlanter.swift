//
//  ForestBuilder.swift
//  Impeller
//
//  Created by Drew McCormack on 09/02/2017.
//  Copyright © 2017 Drew McCormack. All rights reserved.
//

import Foundation

/// Makes a forest from a tree of Repositables
final class ForestPlanter {
    
    var forest = Forest()
    
    init<T:Repositable>(withRoot root:T) {
        plant(withRoot: root)
    }
    
    private func plant<T:Repositable>(withRoot repositable:T) {
        let treePlanter = ValueTreePlanter(repositable:repositable, forestPlanter: self)
        forest.update(treePlanter.valueTree)
    }
    
    func processChild<T:Repositable>(_ child: T) {
        plant(withRoot: child)
    }
}
