//
//  ShapesView.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/6.
//

import SwiftUI

struct ShapesView: View {
    let strokeWidth: CGFloat = 4
    let shapeScale: CGFloat = 96
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .stroke(lineWidth: strokeWidth)
                .frame(width: shapeScale, height: shapeScale)
            
            Rectangle()
                .stroke(lineWidth: strokeWidth)
                .frame(width: shapeScale, height: shapeScale)
            
            TriangleShape(
                point1: .zero,
                point2: .init(x: shapeScale, y: shapeScale),
                point3: .init(x: 0, y: shapeScale))
            .stroke(lineWidth: strokeWidth)
            .frame(width: shapeScale, height: shapeScale)
            
            LineShape()
                .stroke(style: .init(lineWidth: strokeWidth, dash: [8 * strokeWidth, 2 * strokeWidth]))
                .frame(width: shapeScale, height: shapeScale)
        }
    }
}

#Preview {
    ShapesView()
}
