//
//  AppModel.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/4.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let globeVolumeID = "globeID"
    var isGlobeVolumeOpen = false
    
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
}
