import SwiftUI

/// The spacing scale. Every padding, spacing, and size sits on a 4 pt grid.
/// Values that differ per device go through Platform.value.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
    /// Page margins. Apple TV pages already sit inside the TV's safe area.
    static var margin: CGFloat { Platform.value(mac: 20, phone: 16, pad: 20, tv: 48, watch: 4, vision: 24) }
    /// Room around focusable controls, where a focused control grows and casts
    /// its shadow. On Apple TV a container without this room cuts the
    /// focused card's edges flat.
    static var focusRoom: CGFloat { Platform.value(mac: 0, phone: 0, pad: 0, tv: 40, watch: 0, vision: 0) }
}

/// Sizes of the item cards on Apple TV.
enum CardSize {
    static var width: CGFloat { Platform.value(mac: 240, phone: 160, pad: 200, tv: 360, watch: 120, vision: 240) }
    static var height: CGFloat { Platform.value(mac: 136, phone: 96, pad: 112, tv: 200, watch: 72, vision: 136) }
    static var gap: CGFloat { Platform.value(mac: 16, phone: 12, pad: 16, tv: 48, watch: 8, vision: 20) }
}
