//
//  Styles.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import SwiftUI

// Buton style with a multitude of customization choices
public struct SimpleButtonStyle: ButtonStyle {
    @State private var hovered = false
    let icon: String
    let iconFlip: String
    let label: String
    let help: String
    let color: Color
    let size: CGFloat
    let padding: CGFloat
    let rotate: Bool

    public init(icon: String, iconFlip: String = "", label: String = "", help: String, color: Color = .primary, size: CGFloat = 20, padding: CGFloat = 5, rotate: Bool = false) {
        self.icon = icon
        self.iconFlip = iconFlip
        self.label = label
        self.help = help
        self.color = color
        self.size = size
        self.padding = padding
        self.rotate = rotate
    }

    public func makeBody(configuration: Self.Configuration) -> some View {
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

// AF button style
public struct AFButtonStyle: ButtonStyle {
    @State private var hovered = false
    @State private var pressed = false
    var image: String
    var fill: Color
    var size: CGFloat

    public init(image: String, fill: Color = .blue, size: CGFloat = 30) {
        self.image = image
        self.fill = fill
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Rectangle()
                .fill(.primary.opacity(0.1))
            Circle()
                .frame(width: configuration.isPressed ? size + 20 : 0, height: configuration.isPressed ? size + 20 : 0)
                .foregroundStyle(fill)
            Image(systemName: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size / 2, height: size / 2)
                .foregroundColor(pressed ? .white : hovered ? .primary : .primary.opacity(0.7))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.3), value: configuration.isPressed)
        .onHover(perform: { hovering in
            hovered = hovering
        })
        .onChange(of: configuration.isPressed) { isPressed in
            pressed = isPressed
        }
    }
}

// Info button that takes some text as input and shows a popover on click
public struct InfoButton: View {
    @State private var isPopoverPresented: Bool = false
    let text: String
    let color: Color
    let label: String
    let warning: Bool
    let edge: Edge
    let extraView: AnyView?

    public init(text: String, color: Color = .primary, label: String = "", warning: Bool = false, edge: Edge = .bottom, extraView: AnyView? = nil) {
        self.text = text
        self.color = color
        self.label = label
        self.warning = warning
        self.edge = edge
        self.extraView = extraView

    }

    public var body: some View {
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
            VStack(spacing: 10) {
                Spacer()

                Text(text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let extraView = extraView {
                    extraView
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 300)
        }
        .padding(.horizontal, 5)
    }
}

// Convenience initializer allowing trailing closure without wrapping in AnyView
extension InfoButton {
    public init<V: View>(text: String, color: Color = .primary, label: String = "", warning: Bool = false, edge: Edge = .bottom, @ViewBuilder extraView: () -> V) {
        self.init(text: text, color: color, label: label, warning: warning, edge: edge, extraView: AnyView(extraView()))
    }
}

// PermissionInfoButton
struct InfoButtonPerms: View {
    @State private var isPopoverPresented: Bool = false
    let color: Color
    let label: String
    let warning: Bool

    public init(color: Color = .primary, label: String = "", warning: Bool = false) {
        self.color = color
        self.label = label
        self.warning = warning

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
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 15) {

                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "externaldrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text("Full Disk permission to access files/folders in system paths")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }

                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "accessibility")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text("Accessibility permission to allow execution of AppleScript")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }

                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "gearshape.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text("Automation permission to perform delete actions via Finder")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }

            }
            .padding()
        }
        .padding(.horizontal, 5)
    }
}



// Animated Button
public struct AniButton: View {
    @State private var show = false

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.1))
            Circle()
                .frame(width: show ? 400 : 0, height: show ? 400 : 0)
                .foregroundStyle(.blue)
            if #available(macOS 14.0, *) {
                Image(systemName: show ? "paintbrush.fill" : "paintbrush")
                    .font(.system(size: 25))
                    .foregroundStyle(show ? .white : .white.opacity(0.5))
                    .contentTransition(.symbolEffect)
            } else if #available(macOS 13.0, *) {
                Image(systemName: show ? "paintbrush.fill" : "paintbrush")
                    .font(.system(size: 25))
                    .foregroundStyle(show ? .white : .white.opacity(0.5))
                    .contentTransition(.opacity)
            } else {
                Image(systemName: show ? "paintbrush.fill" : "paintbrush")
                    .font(.system(size: 25))
                    .foregroundStyle(show ? .white : .white.opacity(0.5))
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn) {
                show.toggle()
            }
        }
    }
}




// TextView override for focus ring and caret color
public extension NSTextView {
    override var frame: CGRect {
        didSet {
            insertionPointColor = NSColor(Color.primary.opacity(0.5)) // Set TextView/TextField caret color
        }
    }

    override var focusRingType: NSFocusRingType {
        get { .none } // Disable focus ring on TextField
        set { }
    }
}



// Alert Badge Notifications
public struct AlertNotification: View {
    var label: String
    var icon: String
    var buttonAction: () -> Void
    var btnColor: Color
    var disabled: Bool = false
    var hideLabel: Bool = false

//    @ObservedObject var themeManager: ThemeManager
    @State private var hovered = false
    @Environment(\.colorScheme) var colorScheme // Access the current color scheme

    public init(label: String, icon: String, buttonAction: @escaping () -> Void, btnColor: Color, disabled: Bool = false, hideLabel: Bool = false) {
        self.label = label
        self.icon = icon
        self.buttonAction = buttonAction
        self.btnColor = btnColor
        self.disabled = disabled
        self.hideLabel = hideLabel
    }

    public var body: some View {
        HStack {
            if !hideLabel {
                Text(label)
                    .font(.title3)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .opacity(0.5)
                    .padding(.leading, 7)

                Spacer()
            }

            HStack(alignment: .center, spacing: 5) {
                Image(systemName: !hovered ? "\(icon)" : "\(icon).fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.white)
                Text(hideLabel ? label : "View")
                    .foregroundStyle(.white)
            }
            .padding(3)
            .buttonStyle(PlainButtonStyle())
            .padding(4)
            .background(btnColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .disabled(disabled)
            .onHover { hover in
                if !disabled {
                    withAnimation {
                        hovered = hover
                    }
                }
            }
        }
        .frame(height: 30)
        .clipShape(Rectangle())
        .onTapGesture {
            buttonAction()
        }
    }
}

// Components Background
public struct CustomBackgroundView: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    var brightness: Double
    var opacity: Double

    public func body(content: Content) -> some View {
        content
            .padding(7)
            .background(themeManager.pickerColor.adjustBrightness(brightness).opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

public extension View {
    func backgroundAF(brightness: Double = 10.0, opacity: Double = 1.0) -> some View {
        self.modifier(CustomBackgroundView(brightness: brightness, opacity: opacity))
    }
}


// Custom progress bar
public struct CustomBarProgressStyle: ProgressViewStyle {
    var trackColor: Color
    var progressColor: Color
    var height: Double = 10.0
    var labelFontStyle: Font = .body

    public func makeBody(configuration: Configuration) -> some View {

        let progress = configuration.fractionCompleted ?? 0.0

        GeometryReader { geometry in

            VStack(alignment: .leading) {

                configuration.label
                    .font(labelFontStyle)

                RoundedRectangle(cornerRadius: 10.0)
                    .fill(trackColor.adjustBrightness())
                    .frame(height: height)
                    .frame(width: geometry.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10.0)
                            .fill(progressColor.luminance())
                            .frame(width: geometry.size.width * progress)
                    }

                if let currentValueLabel = configuration.currentValueLabel {
                    currentValueLabel
                        .font(.callout)
                        .foregroundColor(progressColor.luminance().opacity(0.5))
                }

            }

        }
    }
}


// Used for testing UI bounds. This adds a border around any view
public extension View {
    func bounds(_ color: Color = .red) -> some View {
        self.border(color, width: 1)
    }
}


// View dimensions
public struct LogViewDimensions: ViewModifier {
    @State private var size: CGSize = .zero

    public func body(content: Content) -> some View {
        content
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateSize(geometry.size)
                    }
                    .onChange(of: geometry.size) { newSize in
                        updateSize(newSize)
                    }
            })
    }

    private func updateSize(_ newSize: CGSize) {
        if size != newSize {
            size = newSize
            printOS("View size changed: \(newSize)")
        }
    }
}

public extension View {
    func logDimensions() -> some View {
        self.modifier(LogViewDimensions())
    }
}


// Make a picker simple with no background
public extension View {
    func minimalistPicker() -> some View {
        self.buttonStyle(.plain)
    }
}


// Image modifier
public struct CustomImage: View {
    var systemName: String
    var size: CGFloat

    public init(systemName: String, size: CGFloat) {
        self.systemName = systemName
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
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

public extension View {
    func material(_ material: NSVisualEffectView.Material = .hudWindow) -> some View {
        self.modifier(MaterialBackground(material: material))
    }
}


// Transparent colored background
public struct BackgroundColorModifier: ViewModifier {
    @ObservedObject var themeManager: ThemeManager
    var brightness: Double
    var opacity: Double

    public func body(content: Content) -> some View {
        ZStack {
            themeManager.pickerColor.adjustBrightness(brightness).opacity(opacity)
                .material()
            content
        }
    }
}

public extension View {
    func materialColor(themeManager: ThemeManager, brightness: Double = 5, opacity: Double = 0.7) -> some View {
        self.modifier(BackgroundColorModifier(themeManager: themeManager, brightness: brightness, opacity: opacity))
    }
}


// Labeled Divider
public struct LabeledDivider: View {
    let label: String

    public init(label: String) {
        self.label = label
    }

    public var body: some View {
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

