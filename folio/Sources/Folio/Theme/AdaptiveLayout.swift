import SwiftUI

enum DeviceClass {
    case compact      // iPhone portrait
    case regular      // iPhone landscape, iPad, Mac
    case mac          // Mac Catalyst specifically

    static func current(horizontalSizeClass: UserInterfaceSizeClass?) -> DeviceClass {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        return horizontalSizeClass == .regular ? .regular : .compact
        #endif
    }
}

extension DeviceClass {
    var libraryColumns: Int {
        switch self {
        case .compact:  return 2
        case .regular:  return 3
        case .mac:      return 4
        }
    }

    /// Maximum width of the readable text column in the reader.
    var readerContentMaxWidth: CGFloat {
        switch self {
        case .compact:  return .infinity
        case .regular:  return 600
        case .mac:      return 680
        }
    }

    /// Horizontal page padding.
    var readerHorizontalPadding: CGFloat {
        switch self {
        case .compact:  return 24
        case .regular:  return 48
        case .mac:      return 60
        }
    }

    /// Top padding (below status bar / title bar).
    var readerTopPadding: CGFloat {
        switch self {
        case .compact:  return 56
        case .regular:  return 64
        case .mac:      return 72
        }
    }

    /// Bottom padding (above home indicator / toolbar).
    var readerBottomPadding: CGFloat {
        switch self {
        case .compact:  return 72
        case .regular:  return 80
        case .mac:      return 88
        }
    }
}
