//
//  ColorPicker.swift
//
//
//  Created by Alin Lupascu on 7/10/24.
//

import Foundation
import SwiftUI


public struct ColorButtonView: View {
    @ObservedObject var appState: AFstate
    @State private var showPopover = false
    @State private var hexCode: String = "#5babe8"
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

    public init(appState: AFstate, templateColors: [Color]? = nil) {
        self.appState = appState
        self.templateColors = templateColors
    }

    public var body: some View {
        let colors = templateColors ?? defaultColors

        Button(action: {
            showPopover = true
        }) {
            Rectangle()
                .fill(appState.themeColor)
                .frame(width: 85, height: 30)
                .cornerRadius(5)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(lineWidth: 1)
                            .foregroundStyle(appState.themeColor.luminance())
                            .opacity(0.3)
                            .shadow(radius: 2)
                        Text(hexCode)
                            .foregroundStyle(appState.themeColor.luminance())
                            .font(.callout)
                    }

                )
                .padding(5)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            ColorPickerSliderView(appState: appState, hexCode: $hexCode, templateColors: .constant(colors))
        }
    }
}


public struct ColorPickerSliderView: View {
    @ObservedObject var appState: AFstate
    @Binding var hexCode: String
    @Binding var templateColors: [Color]
    @Environment(\.dismiss) var dismiss

    public init(appState: AFstate, hexCode: Binding<String>, templateColors: Binding<[Color]>) {
        self.appState = appState
        self._hexCode = hexCode
        self._templateColors = templateColors
    }

    public var body: some View {

        VStack(spacing: 15) {

            // Top Bar
            VStack(spacing: 5) {
                // Hex code input
                HStack {
                    Button("") {
                        copyToClipboard(hexCode)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "list.clipboard", help: "Copy", size: 18))

                    Spacer()

                    TextField("Enter hex code", text: $hexCode)
                        .textFieldStyle(.plain)
                        .padding(5)
                        .onChange(of: hexCode) { newVal in
                            if !newVal.starts(with: "#") {
                                hexCode = "#" + newVal
                            }
                            if newVal.count > 7 {
                                hexCode = String(newVal.prefix(7))
                            }
                            updateRGBValues(from: hexCode)
                        }
                        .frame(width: 65)

                    Spacer()

                    Button("") {
                        dismiss()
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "x.circle", help: "Close", size: 18))
                }

                HStack {
                    Spacer()
                    Text("Supports 6 character hex code").font(.footnote).opacity(0.5)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .edgesIgnoringSafeArea(.all)
            .padding(5)
            .padding(.horizontal, 4)


            VStack(spacing: 15) {
                // Red slider
                HStack {
                    Text("R").font(.footnote).opacity(0.5)
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(.sRGB, red: 0, green: appState.green, blue: appState.blue, opacity: 1), Color(.sRGB, red: 1, green: appState.green, blue: appState.blue, opacity: 1)]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 6)
                            .cornerRadius(10)

                        Slider(value: $appState.red, in: 0...1)
                            .opacity(0.0)
                            .background(ThumbView(value: $appState.red, range: 0...1))
                            .onChange(of: appState.red) { newVal in
                                updateHexCode()
                            }
                    }
                    .shadow(radius: 1)

                    Text(String(format: "%.2f", appState.red)).font(.footnote).opacity(0.5)
                }


                // Green slider
                HStack {
                    Text("G").font(.footnote).opacity(0.5)
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(.sRGB, red: appState.red, green: 0, blue: appState.blue, opacity: 1), Color(.sRGB, red: appState.red, green: 1, blue: appState.blue, opacity: 1)]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 6)
                            .cornerRadius(10)

                        Slider(value: $appState.green, in: 0...1)
                            .opacity(0.0)
                            .background(ThumbView(value: $appState.green, range: 0...1))
                            .onChange(of: appState.green) { newVal in
                                updateHexCode()
                            }
                    }
                    .shadow(radius: 1)

                    Text(String(format: "%.2f", appState.green)).font(.footnote).opacity(0.5)
                }


                // Blue slider
                HStack {
                    Text("B").font(.footnote).opacity(0.5)
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color(.sRGB, red: appState.red, green: appState.green, blue: 0, opacity: 1), Color(.sRGB, red: appState.red, green: appState.green, blue: 1, opacity: 1)]), startPoint: .leading, endPoint: .trailing)
                            .frame(height: 6)
                            .cornerRadius(10)

                        Slider(value: $appState.blue, in: 0...1)
                            .opacity(0.0)
                            .background(ThumbView(value: $appState.blue, range: 0...1))
                            .onChange(of: appState.blue) { newVal in
                                updateHexCode()
                            }
                    }
                    .shadow(radius: 1)

                    Text(String(format: "%.2f", appState.blue)).font(.footnote).opacity(0.5)
                }


                // Color selection
                HStack {
                    ForEach(templateColors, id: \.self) { color in
                        Rectangle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                            .onTapGesture {
                                setColorFrom(color: color)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(lineWidth: 1)
                                    .opacity(0.3)
                                    .shadow(radius: 2)
                            )
                    }
                }

            }
            .padding([.horizontal, .bottom], 15)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateRGBValues(from: hexCode)
        }
    }

    public func updateRGBValues(from hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if sanitizedHex.count == 6, let intCode = Int(sanitizedHex, radix: 16) {
            appState.red = Double((intCode >> 16) & 0xFF) / 255.0
            appState.green = Double((intCode >> 8) & 0xFF) / 255.0
            appState.blue = Double(intCode & 0xFF) / 255.0
        }
    }

    public func updateHexCode() {
        hexCode = String(format: "#%02x%02x%02x", Int(appState.red * 255), Int(appState.green * 255), Int(appState.blue * 255))
    }

    public func setColorFrom(color: Color) {
        if let components = color.cgColor?.components, components.count >= 3 {
            appState.red = components[0]
            appState.green = components[1]
            appState.blue = components[2]
            updateHexCode()
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



public func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

public extension Color {
    func luminance() -> Color {
        let components = self.cgColor?.components
        let red = components?[0] ?? 0
        let green = components?[1] ?? 0
        let blue = components?[2] ?? 0

        // Calculate the relative luminance
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        // Use a threshold to determine if the color is bright or dark
        return luminance > 0.65 ? Color.black : Color.white
    }
}
