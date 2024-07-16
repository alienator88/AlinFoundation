//
//  ThemeManager.swift
//
//
//  Created by Alin Lupascu on 7/11/24.
//

import Foundation
import SwiftUI

//MARK: ThemeManager

public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    private let userDefaults = UserDefaults.standard
    private let appearanceObserver = AppearanceObserver()
    @Environment(\.colorScheme) private var colorScheme

    @Published public var pickerColor: Color {
        didSet {
            savePickerColor()
        }
    }

    @Published public var hexCode: String = ""

    private var previousColor: Color {
        didSet {
            savePreviousColor()
        }
    }

    @Published public var themeMode: ThemeMode {
        didSet {
            saveThemeMode()
            setupAppearance()
        }
    }

    @Published public var displayMode: DisplayMode {
        didSet {
            saveDisplayMode()
        }
    }

    public enum ThemeMode: String {
        case auto, light, dark, custom
    }


    // Color for #f6f7f7
    let lightColor = Color(.sRGB, red: 246.0 / 255.0, green: 247.0 / 255.0, blue: 247.0 / 255.0, opacity: 1.0)
    // Color for #282828
    let darkColor = Color(.sRGB, red: 40.0 / 255.0, green: 40.0 / 255.0, blue: 40.0 / 255.0, opacity: 1.0)
    // Default color for #303543
    let defaultColor = Color(.sRGB, red: 48.0 / 255.0, green: 53.0 / 255.0, blue: 67.0 / 255.0, opacity: 1.0)

    private init() {
        self.previousColor = userDefaults.color(forKey: "alinfoundation.theme.previousColor") ?? .clear
        self.displayMode = DisplayMode(rawValue: userDefaults.integer(forKey: "alinfoundation.theme.displayMode")) ?? .system
        self.pickerColor = userDefaults.color(forKey: "alinfoundation.theme.pickerColor") ?? defaultColor
        self.previousColor = defaultColor
        self.themeMode = ThemeMode(rawValue: userDefaults.string(forKey: "alinfoundation.theme.mode") ?? "custom") ?? .custom
    }

    private func updatePreviousColorIfNeeded() {
        if previousColor != pickerColor && pickerColor != .clear {
            previousColor = pickerColor
        }
    }

    private func savePreviousColor() {
        userDefaults.setColor(previousColor, forKey: "alinfoundation.theme.previousColor")
    }

    private func saveThemeMode() {
        userDefaults.set(themeMode.rawValue, forKey: "alinfoundation.theme.mode")
    }

    private func savePickerColor() {
        userDefaults.setColor(pickerColor, forKey: "alinfoundation.theme.pickerColor")
        if themeMode == .custom {
            updatePreviousColorIfNeeded()
        }
    }

    private func saveDisplayMode() {
        userDefaults.set(displayMode.rawValue, forKey: "alinfoundation.theme.displayMode")
    }

    public func setupAppearance() {
        switch themeMode {
        case .auto:
            setupAutoTheme()
        case .light:
            setupForcedTheme(dark: false)
        case .dark:
            setupForcedTheme(dark: true)
        case .custom:
            setupCustomTheme()
        }
    }

    public func setupAutoTheme() {
        let isDarkMode = isDarkMode()
        pickerColor = isDarkMode ? darkColor : lightColor
        displayMode = isDarkMode ? .dark : .light
        hexCode = pickerColor.toHex()
    }

    private func setupForcedTheme(dark: Bool) {
        pickerColor = dark ? darkColor : lightColor
        displayMode = dark ? .dark : .light
    }

    private func setupCustomTheme() {
        pickerColor = previousColor
        pickerColor.luminanceDisplayMode()
    }

}


//MARK: AppearanceObserver

public class AppearanceObserver {
    private var observer: NSObjectProtocol?

    public init() {
        setupObserver()
    }

    private func setupObserver() {
        observer = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.handleAppearanceChange()
        }
    }

    private func handleAppearanceChange() {
        let themeManager = ThemeManager.shared
        if themeManager.themeMode == .auto {
            themeManager.setupAppearance()
        }
    }

    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}




public enum DisplayMode: Int, CaseIterable {
    case system, dark, light

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    public var description: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}



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
