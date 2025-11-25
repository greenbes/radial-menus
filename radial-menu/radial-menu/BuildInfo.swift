//
//  BuildInfo.swift
//  radial-menu
//
//  Provides build identification information.
//  BuildInfo.generated.swift is created by scripts/generate-build-info.sh
//

import Foundation

/// Build identification and metadata
enum BuildInfo {
    /// Full git commit hash
    static var commitHash: String {
        GeneratedBuildInfo.commitHash
    }

    /// Short git commit hash (first 7 characters)
    static var shortCommitHash: String {
        String(commitHash.prefix(7))
    }

    /// Build timestamp in ISO 8601 format
    static var buildTimestamp: String {
        GeneratedBuildInfo.buildTimestamp
    }

    /// Git branch name at build time
    static var branch: String {
        GeneratedBuildInfo.branch
    }

    /// Whether the working directory had uncommitted changes
    static var isDirty: Bool {
        GeneratedBuildInfo.isDirty
    }

    /// Combined build ID string (e.g., "abc1234-dirty")
    static var buildID: String {
        var id = shortCommitHash
        if isDirty {
            id += "-dirty"
        }
        return id
    }

    /// Human-readable build description
    static var description: String {
        var desc = "Build \(buildID) on \(branch)"
        desc += "\nBuilt: \(buildTimestamp)"
        return desc
    }
}
