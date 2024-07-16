//
//  ColorPicker.swift
//
//
//  Created by Alin Lupascu on 7/10/24.
//

import Foundation
import SwiftUI


public struct ColorButtonView: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var showPopover = false
    var templateColors: [Color]?

    private let defaultColors: [Color] = [
        Color(.sRGB, red: 1.0, green: 0.0, blue: 0.0, opacity: 1), // Red
        Color(.sRGB, red: 0.0, green: 1.0, blue: 0.0, opacity: 1), // Green
        Color(.sRGB, red: 0.0, green: 0.0, blue: 1.0, opacity: 1), // Blue
        Color(.sRGB, red: 1.0, green: 1.0, blue: 0.0, opacity: 1), // Yellow
        Color(.sRGB, red: 1.0, green: 0.5, blue: 0.0, opacity: 1), // Orange
        Color(.sRGB, red: 0.5, green: 0.0, blue: 0.69, opacity: 1), // Purple
        Color(.sRGB, red: 0.36, green: 0.67, blue: 0.91, opacity: 1)  // Baby Blue
    ]

    public init(themeManager: ThemeManager, templateColors: [Color]? = nil) {
        self.themeManager = themeManager
        self.templateColors = templateColors
    }

    public var body: some View {
        let colors = templateColors ?? defaultColors

        Button(action: {
            if themeManager.themeMode != .custom {
                themeManager.themeMode = .custom
            }
            showPopover = true
        }) {
            RoundedRectangle(cornerRadius: 5)
                .fill(themeManager.pickerColor)
                .frame(width: 22, height: 22)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(lineWidth: 0.8)
                            .foregroundStyle(themeManager.pickerColor.luminance())
                            .opacity(0.3)
                    }

                )
        }
        .help("Current color: \(themeManager.hexCode)")
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            ColorPickerSliderView(themeManager: themeManager, templateColors: .constant(colors))
        }
        .onAppear(perform: updateHexCode)
        .onChange(of: themeManager.pickerColor) { _ in
            updateHexCode()
        }
    }
    
    private func updateHexCode() {
        themeManager.hexCode = themeManager.pickerColor.toHex()
    }
}


public struct ColorPickerSliderView: View {
    @ObservedObject var themeManager: ThemeManager
    @Binding var templateColors: [Color]
    @Environment(\.dismiss) var dismiss
    @State private var red: Double = 0
    @State private var green: Double = 0
    @State private var blue: Double = 0

    public init(themeManager: ThemeManager, templateColors: Binding<[Color]>) {
        self.themeManager = themeManager
        self._templateColors = templateColors
    }

    public var body: some View {

        VStack(spacing: 15) {

            // Top Bar
            VStack(spacing: 5) {
                // Hex code input
                HStack {
                    Button("") {
                        copyToClipboard(themeManager.hexCode)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "doc.on.doc", help: "Copy", size: 18))

                    Spacer()

                    TextField("Enter hex code", text: $themeManager.hexCode)
                        .textFieldStyle(.plain)
                        .padding(5)
                        .onChange(of: themeManager.hexCode) { newVal in
                            // Only update if the new value is different
                            let validHex = processHexCode(newVal)
                            if themeManager.hexCode != validHex {
                                themeManager.hexCode = validHex
                            }
                            if validHex.count == 7 {
                                updateRGBValues(from: Color(hex: themeManager.hexCode) ?? Color.white)
                            }

                        }
                        .frame(width: 70)

                    Spacer()

                    Button("") {
                        themeManager.setupAutoTheme()
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "arrow.counterclockwise.circle", help: "Reset", size: 18))

                }

            }
            .frame(maxWidth: .infinity)
            .edgesIgnoringSafeArea(.all)
            .padding(5)
            .padding(.horizontal, 4)


            VStack(spacing: 15) {
                // Red slider
                HStack {
                    Text("R").font(.footnote).opacity(0.5).frame(width: 25)
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(.sRGB, red: 0, green: green, blue: blue, opacity: 1), Color(.sRGB, red: 1, green: green, blue: blue, opacity: 1)]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 6)
                            .cornerRadius(10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(lineWidth: 0.8)
                                    .opacity(0.5)
                            }


                        Slider(value: $red, in: 0...1)
                            .opacity(0.0)
                            .background(ThumbView(value: $red, range: 0...1))
                            .onChange(of: red) { newVal in
                                updatePickerColor()
                            }
                    }
                    .shadow(radius: 1)

                    Text(String(format: "%d", Int(red * 255))).font(.footnote).opacity(0.5).frame(width: 25)
                }


                // Green slider
                HStack {
                    Text("G").font(.footnote).opacity(0.5).frame(width: 25)
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(.sRGB, red: red, green: 0, blue: blue, opacity: 1), Color(.sRGB, red: red, green: 1, blue: blue, opacity: 1)]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 6)
                            .cornerRadius(10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(lineWidth: 0.8)
                                    .opacity(0.5)
                            }

                        Slider(value: $green, in: 0...1)
                            .opacity(0.0)
                            .background(ThumbView(value: $green, range: 0...1))
                            .onChange(of: green) { newVal in
                                updatePickerColor()
                            }
                    }
                    .shadow(radius: 1)

                    Text(String(format: "%d", Int(green * 255))).font(.footnote).opacity(0.5).frame(width: 25)
                }


                // Blue slider
                HStack {
                    Text("B").font(.footnote).opacity(0.5).frame(width: 25)
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(.sRGB, red: red, green: green, blue: 0, opacity: 1), Color(.sRGB, red: red, green: green, blue: 1, opacity: 1)]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 6)
                            .cornerRadius(10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(lineWidth: 0.8)
                                    .opacity(0.5)
                            }

                        Slider(value: $blue, in: 0...1)
                            .opacity(0.0)
                            .background(ThumbView(value: $blue, range: 0...1))
                            .onChange(of: blue) { newVal in
                                updatePickerColor()
                            }
                    }
                    .shadow(radius: 1)

                    Text(String(format: "%d", Int(blue * 255))).font(.footnote).opacity(0.5).frame(width: 25)
                }


                // Color selection
                HStack(spacing: 20) {
                    ForEach(templateColors, id: \.self) { color in
                        Rectangle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .cornerRadius(3)
                            .onTapGesture {
                                setColorFrom(color: color)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(lineWidth: 1)
                                    .opacity(0.5)
                            )
                    }

                }

            }
            .padding([.horizontal], 15)

            HStack {
                Spacer()

                Button("Close") {
                    dismiss()
                }
                .padding(5)

                Spacer()
            }
            .padding(.bottom)

        }
        .frame(minWidth: 250)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateRGBValues(from: themeManager.pickerColor)
        }
        .background(themeManager.pickerColor.padding(-80))
    }

    private func processHexCode(_ hex: String) -> String {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hexSanitized.starts(with: "#") {
            hexSanitized = "#" + hexSanitized
        }
        if hexSanitized.count > 7 {
            hexSanitized = String(hexSanitized.prefix(7))
        }
        return hexSanitized
    }

    private func updateRGBValues(from color: Color) {
        let components = NSColor(color).cgColor.components ?? []
        red = components.count > 0 ? Double(components[0]) : 0
        green = components.count > 1 ? Double(components[1]) : 0
        blue = components.count > 2 ? Double(components[2]) : 0
        updatePickerColor()
    }

    public func updateRGBValuesHex(from hex: String) {
        if let color = Color(hex: hex) {
            let components = NSColor(color).cgColor.components ?? []
            red = components.count > 0 ? Double(components[0]) : 0
            green = components.count > 1 ? Double(components[1]) : 0
            blue = components.count > 2 ? Double(components[2]) : 0
            updatePickerColor()
        }
    }

    public func updatePickerColor() {
        themeManager.pickerColor = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        themeManager.pickerColor.luminanceDisplayMode()
        themeManager.hexCode = themeManager.pickerColor.toHex()
    }

    public func setColorFrom(color: Color) {
        if let components = color.cgColor?.components, components.count >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
            updatePickerColor()
        }
    }



}


public struct ThumbView: View {
    @Binding var value: Double
    public var range: ClosedRange<Double>

    public init(value: Binding<Double>, range: ClosedRange<Double>) {
        self._value = value
        self.range = range
    }

    public var body: some View {
        GeometryReader { geometry in
            Circle()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
                .opacity(0.8)
                .shadow(radius: 1)
                .offset(x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 8, y: 2)
                .gesture(
                    DragGesture().onChanged { gesture in
                        let newValue = Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                        self.value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                )
        }
    }
}
