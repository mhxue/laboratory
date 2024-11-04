//
//  vision_os_labApp.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/4.
//

import SwiftUI

@main
struct vision_os_labApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .background(.black.opacity(0.5))
        }
        .windowStyle(.plain)
        
        WindowGroup(id: appModel.globeVolumeID) {
            Globe()
        }
        .windowStyle(.volumetric)
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
