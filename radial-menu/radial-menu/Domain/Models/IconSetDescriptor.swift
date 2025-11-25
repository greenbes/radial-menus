//
//  IconSetDescriptor.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/25/25.
//

import Foundation

/// Source of an icon set (built-in or user-installed)
enum IconSetSource: String, Codable, Equatable {
    case bundle   // Built-in, shipped with the app
    case user     // User-installed in Application Support
}

/// Describes an icon set's identity and metadata (pure value type)
struct IconSetDescriptor: Equatable, Hashable, Codable, Identifiable {
    /// Unique identifier used internally (e.g., "outline", "my-custom-set")
    let identifier: String

    /// Human-readable display name for UI
    let name: String

    /// Optional description of the icon set
    let description: String?

    /// Optional author information
    let author: Author?

    /// Where this icon set comes from
    let source: IconSetSource

    var id: String { identifier }

    init(
        identifier: String,
        name: String,
        description: String? = nil,
        author: Author? = nil,
        source: IconSetSource
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.author = author
        self.source = source
    }
}

// MARK: - Author

extension IconSetDescriptor {
    /// Author information for an icon set
    struct Author: Codable, Equatable, Hashable {
        let name: String?
        let url: String?
        let email: String?

        init(name: String? = nil, url: String? = nil, email: String? = nil) {
            self.name = name
            self.url = url
            self.email = email
        }
    }
}
