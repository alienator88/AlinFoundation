//
//  ThemeSettingsView.swift
//
//
//  Created by Alin Lupascu on 7/11/24.
//

import Foundation
import SwiftUI


//MARK: ThemeSettingsView
public struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var opacity: Double

    public init(opacity: Double = 1.0) {
        self.opacity = opacity
    }

    public var body: some View {

        let templateColors: [Color] = [
            Color(.sRGB, red: 48.0 / 255.0, green: 49.0 / 255.0, blue: 58.0 / 255.0, opacity: 1.0),  // Slate
            Color(.sRGB, red: 0.188143, green: 0.208556, blue: 0.262679, opacity: 1),  // SlatePurple
            Color(.sRGB, red: 0.117257, green: 0.22506, blue: 0.249171, opacity: 1),    // Solarized
            Color(.sRGB, red: 0.268614, green: 0.264737, blue: 0.383503, opacity: 1),  // Dracula
            Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1)   // macOS
        ]

        HStack {
            CustomRadioButton(themeManager: themeManager, isSelected: themeManager.themeMode == .auto, image: "circle.lefthalf.filled") {
                themeManager.themeMode = .auto
            }
            .tag(ThemeManager.ThemeMode.auto)

            CustomRadioButton(themeManager: themeManager, isSelected: themeManager.themeMode == .light, image: "sun.max.fill") {
                themeManager.themeMode = .light
            }
            .tag(ThemeManager.ThemeMode.light)

            CustomRadioButton(themeManager: themeManager, isSelected: themeManager.themeMode == .dark, image: "moon.fill") {
                themeManager.themeMode = .dark
            }
            .tag(ThemeManager.ThemeMode.dark)

            CustomRadioButton(themeManager: themeManager, isSelected: themeManager.themeMode == .custom, image: "paintbrush.fill", templateColors: templateColors) {
                themeManager.themeMode = .custom
            }
            .tag(ThemeManager.ThemeMode.custom)
        }

    }
}




struct CustomRadioButton: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var showPopover = false
    let isSelected: Bool
    var image: String
    var templateColors: [Color]?
    var action: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.primary.opacity(0.1))
            Circle()
                .frame(width: isSelected ? 50 : 0, height: isSelected ? 50 : 0)
                .foregroundStyle(.blue)
            Image(systemName: image)
                .font(.system(size: 15))
                .foregroundColor(isSelected ? .white : .primary.opacity(0.3))
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn) {
                action()
                if themeManager.themeMode == .custom {
                    showPopover.toggle()
                }
            }
        }
        .popover(isPresented: $showPopover) {
            ColorPickerSliderView(themeManager: themeManager, templateColors: .constant(templateColors ?? []))
        }
    }
}
