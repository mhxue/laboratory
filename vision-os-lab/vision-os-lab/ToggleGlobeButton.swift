//
//  Untitled.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/4.
//

import SwiftUI

struct ToggleGlobeButton: View {

    @Environment(AppModel.self) private var appModel

    @Environment(\.dismissWindow) private var dismissVolumetric
    @Environment(\.openWindow) private var openVolumetric

    var body: some View {
        Button {
            if appModel.isGlobeVolumeOpen {
                dismissVolumetric(id: appModel.globeVolumeID)
            } else {
                openVolumetric(id: appModel.globeVolumeID)
            }
            appModel.isGlobeVolumeOpen.toggle()
        } label: {
            Text(appModel.isGlobeVolumeOpen ? "Hide Globe Volume" : "Show Globe Volume")
        }
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
