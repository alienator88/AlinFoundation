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

    private init() {
        self.previousColor = userDefaults.color(forKey: "alinfoundation.theme.previousColor") ?? .clear
        self.displayMode = DisplayMode(rawValue: userDefaults.integer(forKey: "alinfoundation.theme.displayMode")) ?? .system
        self.pickerColor = userDefaults.color(forKey: "alinfoundation.theme.pickerColor") ?? .clear
        self.themeMode = ThemeMode(rawValue: userDefaults.string(forKey: "alinfoundation.theme.mode") ?? "auto") ?? .auto
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
        updatePreviousColorIfNeeded()
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
