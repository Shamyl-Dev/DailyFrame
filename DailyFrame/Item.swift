//
//  Item.swift
//  DailyFrame
//
//  Created by Shamyl Khan on 7/1/25.
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
