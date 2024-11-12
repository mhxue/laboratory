//
//  TriangleShape.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/6.
//

import SwiftUI

struct TriangleShape: Shape {
    let point1: CGPoint
    let point2: CGPoint
    let point3: CGPoint
    
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: point1)
        path.addLine(to: point2)
        path.addLine(to: point3)
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    TriangleShape(point1: .zero, point2: .init(x: 100, y: 100), point3: .init(x: 0, y: 100))
        .stroke(lineWidth: 4)
        .frame(width: 100, height: 100)
}
