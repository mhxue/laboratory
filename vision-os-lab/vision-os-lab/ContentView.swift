//
//  ContentView.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/4.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @State private var scale = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Model3D(named: "Scene", bundle: realityKitContentBundle)

                RealityView { content in
                    let sphereContent = ModelEntity(
                        mesh: .generateSphere(radius: 0.1),
                        materials: [SimpleMaterial(color: .white, isMetallic: true)]
                    )
                
                    sphereContent.components.set(InputTargetComponent())
                    sphereContent.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.1)]))
                
                    content.add(sphereContent)
                } update: { content in
                    if let entity = content.entities.first {
                        entity.transform.scale = scale ? [1.2, 1.2, 1.2] : [1.0, 1.0, 1.0]
                    }
                }
                .gesture(TapGesture().targetedToAnyEntity().onEnded({ _ in
                    scale.toggle()
                }))
                
                Text("Hello, world!")

                ToggleGlobeButton()
                
                ToggleImmersiveSpaceButton()
                
                NavigationLink(value: Module.twoDimensionShapes) {
                    Text("2D Shapes")
                }
                
                NavigationLink(value: Module.threeDimensionShapres) {
                    Text("3D Shapes")
                }
                
                
                NavigationLink(value: Module.turnTable) {
                    Text("Turn Table")
                }
                
                NavigationLink(value: Module.depthEffect) {
                    Text("Depth Effect")
                }
            }
            .padding()
            .navigationDestination(for: Module.self) { module in
                switch module {
                case .twoDimensionShapes:
                    ShapesView()
                case .threeDimensionShapres:
                    ThreeDShapeViews()
                case .turnTable:
                    TurnTableEntranceView()
                case .depthEffect:
                    DepthEffect()
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
