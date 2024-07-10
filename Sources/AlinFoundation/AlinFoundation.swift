//
//  AlinFoundation.swift
//
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import SwiftUI

// MARK: Main application state for AlinFoundation package

public class AFstate: ObservableObject {

    /// ColorPicker
    var red: Double = 0.356 { didSet { updateThemeColor() }}
    var green: Double = 0.671 { didSet { updateThemeColor() }}
    var blue: Double = 0.910 { didSet { updateThemeColor() }}

    @Published public var themeColor: Color

    public init() {
        self.themeColor = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    private func updateThemeColor() {
        themeColor = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Other

}
