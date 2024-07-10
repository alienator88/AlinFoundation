//
//  Styles.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import SwiftUI

// Buton style with a multitude of customization choices
struct SimpleButtonStyle: ButtonStyle {
    @State private var hovered = false
    let icon: String
    let iconFlip: String
    let label: String
    let help: String
    let color: Color
    let size: CGFloat
    let padding: CGFloat
    let rotate: Bool

    init(icon: String, iconFlip: String = "", label: String = "", help: String, color: Color = .primary, size: CGFloat = 20, padding: CGFloat = 5, rotate: Bool = false) {
        self.icon = icon
        self.iconFlip = iconFlip
        self.label = label
        self.help = help
        self.color = color
        self.size = size
        self.padding = padding
        self.rotate = rotate
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        HStack(alignment: .center) {
            Image(systemName: (hovered && !iconFlip.isEmpty) ? iconFlip : icon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
//                .scaleEffect(hovered ? 1.05 : 1.0)
                .rotationEffect(.degrees(rotate ? (hovered ? 90 : 0) : 0))
                .animation(.easeInOut(duration: 0.2), value: hovered)
            if !label.isEmpty {
                Text(label)
            }
        }
        .foregroundColor(hovered ? color.opacity(0.5) : color)
        .padding(padding)
        .onHover { hovering in
            withAnimation() {
                hovered = hovering
            }
        }
        .scaleEffect(configuration.isPressed ? 0.90 : 1)
        .help(help)
    }
}

// Info button that takes some text as input and shows a popover on click
struct InfoButton: View {
    @State private var isPopoverPresented: Bool = false
    let text: String
    let color: Color
    let label: String
    let warning: Bool
    let edge: Edge

    init(text: String, color: Color = .primary, label: String = "", warning: Bool = false, edge: Edge = .bottom) {
        self.text = text
        self.color = color
        self.label = label
        self.warning = warning
        self.edge = edge

    }

    var body: some View {
        Button(action: {
            self.isPopoverPresented.toggle()
        }) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: !warning ? "info.circle.fill" : "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundColor(!warning ? color.opacity(0.7) : color)
                    .frame(height: 16)
                if !label.isEmpty {
                    Text(label)
                        .font(.callout)
                        .foregroundColor(color.opacity(0.7))

                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: edge) {
            VStack {
                Spacer()
                Text(text)
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding()
                Spacer()
            }
            .frame(width: 300)
        }
        .padding(.horizontal, 5)
    }
}


// Rounded textfield style
struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(8)
            .cornerRadius(6)
            .textFieldStyle(.plain)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.primary.opacity(0.4), lineWidth: 0.8)
            )
    }
}


// Used for testing UI bounds. This adds a border around any view
extension View {
    func bounds() -> some View {
        self.border(Color.red, width: 1)
    }
}

// Make a picker simple with no background
extension View {
    func minimalistPicker() -> some View {
        self.buttonStyle(.plain)
    }
}


/// Transparent view modifier
/// Use .material() on a view
/// Can also use .material(.sidebar) to specify material
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


// Labeled Divider
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

