import AppKit

/// Reads the app's actual accessibility tree. This is not a VoiceOver session.
/// SwiftUI's AccessibilityNode does not declare NSAccessibility conformance;
/// their public Objective-C accessibility accessors remain available.
@MainActor enum NativeAccessibility {
    struct Element {
        let object: NSObject
        func attribute(_ name: NSAccessibility.Attribute) -> Any? {
            let key: String
            switch name {
            case .children: key = "accessibilityChildren"
            case .role: key = "accessibilityRole"
            case .title, .description: key = "accessibilityLabel"
            case .value: key = "accessibilityValue"
            case .position, .size: key = "accessibilityFrame"
            default: return nil
            }
            // SwiftUI exposes these Objective-C accessors without declaring
            // the full protocol. KVC also boxes the NSRect return value safely.
            guard object.responds(to: NSSelectorFromString(key)) else { return nil }
            let value = object.value(forKey: key)
            if name == .position, let rect = value as? NSValue { return NSValue(point: rect.rectValue.origin) }
            if name == .size, let rect = value as? NSValue { return NSValue(size: rect.rectValue.size) }
            return value
        }
        var role: NSAccessibility.Role? {
            (attribute(.role) as? String).map { NSAccessibility.Role(rawValue: $0) }
        }
        var label: String? { (attribute(.title) as? String) ?? (attribute(.description) as? String) }
        var text: String? { (attribute(.value) as? String) ?? label }
        var frame: NSRect? {
            guard let position = attribute(.position) as? NSValue, let size = attribute(.size) as? NSValue else { return nil }
            return NSRect(origin: position.pointValue, size: size.sizeValue)
        }
    }

    static func elements(in root: Any, depth: Int = 0) -> [Element] {
        guard depth < 30, let object = root as? NSObject else { return [] }
        let element = Element(object: object)
        let children = element.attribute(.children) as? [Any] ?? []
        return [element] + children.flatMap { elements(in: $0, depth: depth + 1) }
    }

    static func button(_ label: String, in root: NSView?) throws -> Element {
        let nodes = root.map { elements(in: $0) } ?? []
        guard let button = nodes.first(where: { $0.role == .button && $0.label == label }) else {
            throw ProbeFailure("Missing native accessibility button: \(label). Nodes: \(nodes.map { [$0.role?.rawValue, $0.label, $0.text] })")
        }
        return button
    }
}
