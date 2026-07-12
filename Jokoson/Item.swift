//
//  Item.swift
//  Jokoson
//
//  Created by Pramuditha Muhammad Ikhwan on 12/07/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
