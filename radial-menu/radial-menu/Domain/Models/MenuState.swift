//
//  MenuState.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

/// Represents the current state of the radial menu
enum MenuState: Equatable {
    case closed
    case opening
    case open(selectedIndex: Int?)
    case executing(itemIndex: Int)
    case closing

    var isVisible: Bool {
        switch self {
        case .closed:
            return false
        case .opening, .open, .executing, .closing:
            return true
        }
    }

    var selectedIndex: Int? {
        switch self {
        case .open(let index):
            return index
        case .executing(let index):
            return index
        default:
            return nil
        }
    }
}
