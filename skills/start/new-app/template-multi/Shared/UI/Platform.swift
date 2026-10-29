import SwiftUI

/// The device the app runs on. Every size, spacing, or behavior that differs
/// per device goes through `Platform.value`, so a number chosen for one device
/// never leaks into another. Every argument is required on purpose: adding a
/// value means deciding it for each device.
///   .padding(Platform.value(mac: 20, phone: 16, pad: 20, tv: 48, watch: 4, vision: 24))
enum Platform: String {
    case mac, phone, pad, tv, watch, vision

    static let current: Platform = {
        #if os(macOS)
        return .mac
        #elseif os(tvOS)
        return .tv
        #elseif os(watchOS)
        return .watch
        #elseif os(visionOS)
        return .vision
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #endif
    }()

    static func value<T>(mac: T, phone: T, pad: T, tv: T, watch: T, vision: T) -> T {
        switch current {
        case .mac: mac
        case .phone: phone
        case .pad: pad
        case .tv: tv
        case .watch: watch
        case .vision: vision
        }
    }
}
