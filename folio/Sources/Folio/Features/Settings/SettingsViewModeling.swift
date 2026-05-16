import Foundation
import EPUBKit

/// ViewModel protocol for the reader settings screen.
@MainActor
protocol SettingsViewModeling: AnyObject, Observable {
    var stylesheet: EPUBStylesheet { get set }
}
