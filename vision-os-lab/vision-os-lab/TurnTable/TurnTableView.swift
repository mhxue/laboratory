//
//  TurnTableView.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/7.
//

import SwiftUI
import RealityKit

struct TurnTableEntranceView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersive
    @Environment(\.dismissImmersiveSpace) private var dismissImmersive
    
    var body: some View {
        Button {
            Task { @MainActor in
                if appModel.isTurnTableOpen {
                    await dismissImmersive()
                } else {
                    await openImmersive(id: appModel.turntableID)
                }
                appModel.isTurnTableOpen.toggle()
            }
        } label: {
            Text(appModel.isTurnTableOpen ? "Hide Turn Table" : "Show Turn Table")
        }
    }
}

struct TurnTableView: View {
    var body: some View {
        RealityView { content in
            let root = Entity()
            content.add(root)
            
            root.position.y += 1.7

            root.addRocks()
            root.components.set(TurnTableComponent())
            
            TurnTableSystem.registerSystem()
        }
    }
}

extension Entity {
    
    static var rockModel: ModelComponent = {
        return try! Entity.loadModel(named: "rock").model!
    }()
    
    func addRocks() {
        for _ in 0..<50 {
            let entity = Entity()
            addChild(entity)
            
            // Set material
            entity.components.set(Self.rockModel)
            
            // Set transformation
            
            let selfRotation = Transform(rotation: simd_quatf(angle: .random(in: 0..<2 * .pi), axis: [0, 1, 0])).matrix
            
            let translation = Transform(translation: [0, 0, 1]).matrix
            
            let publicRotationX = Transform(rotation: simd_quatf(angle: .random(in: (-.pi / 10)..<(.pi/10)), axis: [1, 0, 0])).matrix
            
            let publicRotationY = Transform(rotation: simd_quatf(angle: .random(in: 0..<2 * .pi), axis: [0, 1, 0])).matrix
            
            entity.transform = Transform(matrix: publicRotationY * publicRotationX * translation * selfRotation)
                        
            // Set scale
            entity.setScale(SIMD3(repeating: 0.001 * .random(in: 0.5...2)), relativeTo: entity)
            
            // Set properties in turn table system
            entity.components.set(TurnTableComponent(
                speed: .random(in: 0...0.1),
                axis: simd_float3(
                    x: .random(in: -1...1),
                    y: .random(in: -1...1),
                    z: .random(in: -1...1)
                )
            ))
        }
    }
}

struct TurnTableComponent: Component {
    var duration: TimeInterval = 0
    let speed: Float
    let axis: simd_float3
    
    init(speed: Float = 0.05 , axis: simd_float3 = [0, 1, 0]) {
        self.speed = speed
        self.axis = axis
    }
}

struct TurnTableSystem: System {
    init(scene: RealityKit.Scene) {
        
    }
    
    func update(context: SceneUpdateContext) {
        let entities = context.entities(matching: EntityQuery(where: .has(TurnTableComponent.self)), updatingSystemWhen: .rendering)
        for entity in entities {
            if var turnTableComponent = entity.components[TurnTableComponent.self] {
                turnTableComponent.duration += context.deltaTime
                entity.components[TurnTableComponent.self] = turnTableComponent
                
                entity.setOrientation(simd_quatf(angle: 0.1 * turnTableComponent.speed, axis: turnTableComponent.axis), relativeTo: entity)
            }
        }
    }
}
