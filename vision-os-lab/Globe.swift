//
//  Globe.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/4.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct Globe: View {
    var body: some View {
        Model3D(
            named: "earth",
            bundle: realityKitContentBundle
        )
    }
}

#Preview {
    Globe()
}
