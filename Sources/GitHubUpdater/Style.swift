//
//  Style.swift
//  
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import SwiftUI


public struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

public struct MaterialBackground: ViewModifier {
    var material: NSVisualEffectView.Material

    public func body(content: Content) -> some View {
        content
            .background(VisualEffectView(material: material))
    }
}

extension View {
    public func material(_ material: NSVisualEffectView.Material = .hudWindow) -> some View {
        self.modifier(MaterialBackground(material: material))
    }
}

struct LabeledDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .opacity(0.2)

            Text(label)
                .textCase(.uppercase)
                .font(.title2)
                .opacity(0.6)
                .padding(.horizontal, 10)
                .frame(minWidth: 80)

            Rectangle()
                .frame(height: 1)
                .opacity(0.2)
        }
        .frame(minHeight: 35)
    }
}
