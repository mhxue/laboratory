//
//  LineShape.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/6.
//

import SwiftUI

struct LineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: .zero)
        path.addLine(to: .init(x: 100, y: 0))
        
        return path
    }
}

#Preview {
    LineShape()
        .stroke(style: .init(lineWidth: 4, dash: [4, 4]))
}
