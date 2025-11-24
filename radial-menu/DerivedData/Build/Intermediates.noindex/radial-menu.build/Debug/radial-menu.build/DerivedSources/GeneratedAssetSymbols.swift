import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "bootstrap_calendar" asset catalog image resource.
    static let bootstrapCalendar = DeveloperToolsSupport.ImageResource(name: "bootstrap_calendar", bundle: resourceBundle)

    /// The "bootstrap_camera" asset catalog image resource.
    static let bootstrapCamera = DeveloperToolsSupport.ImageResource(name: "bootstrap_camera", bundle: resourceBundle)

    /// The "bootstrap_folder" asset catalog image resource.
    static let bootstrapFolder = DeveloperToolsSupport.ImageResource(name: "bootstrap_folder", bundle: resourceBundle)

    /// The "bootstrap_globe" asset catalog image resource.
    static let bootstrapGlobe = DeveloperToolsSupport.ImageResource(name: "bootstrap_globe", bundle: resourceBundle)

    /// The "bootstrap_journal" asset catalog image resource.
    static let bootstrapJournal = DeveloperToolsSupport.ImageResource(name: "bootstrap_journal", bundle: resourceBundle)

    /// The "bootstrap_list" asset catalog image resource.
    static let bootstrapList = DeveloperToolsSupport.ImageResource(name: "bootstrap_list", bundle: resourceBundle)

    /// The "bootstrap_terminal" asset catalog image resource.
    static let bootstrapTerminal = DeveloperToolsSupport.ImageResource(name: "bootstrap_terminal", bundle: resourceBundle)

    /// The "bootstrap_volume_mute" asset catalog image resource.
    static let bootstrapVolumeMute = DeveloperToolsSupport.ImageResource(name: "bootstrap_volume_mute", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "bootstrap_calendar" asset catalog image.
    static var bootstrapCalendar: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapCalendar)
#else
        .init()
#endif
    }

    /// The "bootstrap_camera" asset catalog image.
    static var bootstrapCamera: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapCamera)
#else
        .init()
#endif
    }

    /// The "bootstrap_folder" asset catalog image.
    static var bootstrapFolder: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapFolder)
#else
        .init()
#endif
    }

    /// The "bootstrap_globe" asset catalog image.
    static var bootstrapGlobe: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapGlobe)
#else
        .init()
#endif
    }

    /// The "bootstrap_journal" asset catalog image.
    static var bootstrapJournal: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapJournal)
#else
        .init()
#endif
    }

    /// The "bootstrap_list" asset catalog image.
    static var bootstrapList: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapList)
#else
        .init()
#endif
    }

    /// The "bootstrap_terminal" asset catalog image.
    static var bootstrapTerminal: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapTerminal)
#else
        .init()
#endif
    }

    /// The "bootstrap_volume_mute" asset catalog image.
    static var bootstrapVolumeMute: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bootstrapVolumeMute)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "bootstrap_calendar" asset catalog image.
    static var bootstrapCalendar: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapCalendar)
#else
        .init()
#endif
    }

    /// The "bootstrap_camera" asset catalog image.
    static var bootstrapCamera: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapCamera)
#else
        .init()
#endif
    }

    /// The "bootstrap_folder" asset catalog image.
    static var bootstrapFolder: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapFolder)
#else
        .init()
#endif
    }

    /// The "bootstrap_globe" asset catalog image.
    static var bootstrapGlobe: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapGlobe)
#else
        .init()
#endif
    }

    /// The "bootstrap_journal" asset catalog image.
    static var bootstrapJournal: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapJournal)
#else
        .init()
#endif
    }

    /// The "bootstrap_list" asset catalog image.
    static var bootstrapList: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapList)
#else
        .init()
#endif
    }

    /// The "bootstrap_terminal" asset catalog image.
    static var bootstrapTerminal: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapTerminal)
#else
        .init()
#endif
    }

    /// The "bootstrap_volume_mute" asset catalog image.
    static var bootstrapVolumeMute: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bootstrapVolumeMute)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

