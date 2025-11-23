//
//  Logger.swift
//  radial-menu
//
//  Created by Steven Greenberg on 11/22/25.
//

import Foundation

class Logger {
    static let shared = Logger()
    private let logFileURL = URL(fileURLWithPath: "/tmp/radial-menu-debug.log")
    
    init() {
        // Ensure file exists
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }
    
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "\(timestamp): \(message)\n"
        
        // Print to standard output/error for immediate feedback if run from terminal
        fputs(logMessage, stderr)
        
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        }
    }
}

func Log(_ message: String) {
    Logger.shared.log(message)
}

