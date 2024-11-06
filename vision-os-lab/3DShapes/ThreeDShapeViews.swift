//
//  ThreeDShapeViews.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/6.
//

import SwiftUI
import RealityKit

struct ThreeDShapeViews: View {
    let radius: Float = 0.05
    let space: Float = 0.1
    let cornerRadius: Float = 0.01
    
    let material = SimpleMaterial(color: .white, isMetallic: false)
    
    var body: some View {
        var xOffset: Float = -0.25
        RealityView { content in
            for entity in entities {
                entity.position.x = xOffset
                content.add(entity)
                xOffset += 0.125
            }
        }
    }
    
    var entities: [Entity] {
        [
            boxEntity,
            roundBoxEntity,
            sphereEntity,
            coneEntity,
            cylinderEntity
        ]
    }
    
    var boxEntity: Entity {
        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateBox(size: 2 * radius), materials: [material]))
        return entity
    }
    
    var roundBoxEntity: Entity {
        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateBox(size: 2 * radius, cornerRadius: cornerRadius), materials: [material]))
        return entity
    }
    
    var sphereEntity: Entity {
        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateSphere(radius: radius), materials: [material]))
        return entity
    }
    
    var coneEntity: Entity {
        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateCone(height: radius * 2, radius: radius), materials: [material]))
        return entity
    }
    
    var cylinderEntity: Entity {
        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateCylinder(height: 2 * radius, radius: radius), materials: [material]))
        return entity
    }
}
