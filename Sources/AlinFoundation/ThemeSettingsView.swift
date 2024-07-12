//
//  ThemeSettingsView.swift
//
//
//  Created by Alin Lupascu on 7/11/24.
//

import Foundation
import SwiftUI

/// Usage:

//import SwiftUI
//import YourThemePackageName
//
//struct SettingsView: View {
//    var body: some View {
//        ThemeSettingsView()
//    }
//}

//MARK: ThemeSettingsView
public struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showLabel: Bool

    public init(showLabel: Bool = false) {
        self.showLabel = showLabel
    }

    public var body: some View {

        let templateColors: [Color] = [
            colorScheme == .light ? Color(.sRGB, red: 0.499549, green: 0.545169, blue: 0.682028, opacity: 1) : Color(.sRGB, red: 48.0 / 255.0, green: 49.0 / 255.0, blue: 58.0 / 255.0, opacity: 1.0),  // Slate
            colorScheme == .light ? Color(.sRGB, red: 0.499549, green: 0.545169, blue: 0.682028, opacity: 1) : Color(.sRGB, red: 0.188143, green: 0.208556, blue: 0.262679, opacity: 1),  // SlatePurple
            colorScheme == .light ? Color(.sRGB, red: 0.554372, green: 0.6557, blue: 0.734336, opacity: 1) : Color(.sRGB, red: 0.117257, green: 0.22506, blue: 0.249171, opacity: 1),    // Solarized
            colorScheme == .light ? Color(.sRGB, red: 0.567094, green: 0.562125, blue: 0.81285, opacity: 1) : Color(.sRGB, red: 0.268614, green: 0.264737, blue: 0.383503, opacity: 1),  // Dracula
            colorScheme == .light ? Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1) : Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1)                          // macOS
        ]


        HStack(alignment: .center, spacing: 5) {

//            Spacer()

            Picker("\(showLabel ? "Theme:" : "")", selection: $themeManager.themeMode) {
                CustomImage(systemName: "circle.lefthalf.filled", size: 15).tag(ThemeManager.ThemeMode.auto).help("Auto")
                CustomImage(systemName: "sun.max", size: 15).tag(ThemeManager.ThemeMode.light).help("Light")
                CustomImage(systemName: "moon", size: 15).tag(ThemeManager.ThemeMode.dark).help("Dark")
                CustomImage(systemName: "paintbrush", size: 15).tag(ThemeManager.ThemeMode.custom).help("Custom")
            }
            .pickerStyle(.segmented)
            .buttonStyle(.borderless)
            .frame(width: 120)
            //            .onChange(of: themeManager.themeMode) { _ in
            //                print(themeManager.pickerColor)
            //                print(themeManager.pickerColor.darker())
            //            }


            /// This shows a minimalistic color picker if Custom theme mode is selected
            if themeManager.themeMode == .custom {
                ColorButtonView(themeManager: themeManager, templateColors: templateColors)
            }

//            Spacer()

        }
        .padding()
    }
}
