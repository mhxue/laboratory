//
//  DepthEffect.swift
//  vision-os-lab
//
//  Created by daniel on 2024/11/7.
//

import SwiftUI

struct DepthEffect: View {
    let layers = 5
    let layerSpacing: CGFloat = 100
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            text
                .foregroundStyle(.black)
                .blur(radius: 12, opaque: false)
            ForEach(0..<layers, id: \.self) { index in
                text
                    .offset(z: CGFloat(index) * layerSpacing * animationProgress)
                    .opacity(CGFloat(index) / CGFloat(layers) * animationProgress)
            }
            text
                .offset(z: CGFloat(layers) * layerSpacing * animationProgress)
        }
        .onAppear {
            let animation = Animation.interpolatingSpring(Spring(stiffness: 100, damping: 10))
            withAnimation(animation) {
                animationProgress = 1.0
            }
        }
    }
    
    let text = Text("Hello").font(.extraLargeTitle)
}

#Preview {
    DepthEffect()
}
