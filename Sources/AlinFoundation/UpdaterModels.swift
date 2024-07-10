//
//  UpdaterModels.swift
//  
//
//  Created by Alin Lupascu on 7/8/24.
//

import Foundation
import SwiftUI

public struct Release: Codable, Identifiable {
    public let id: Int
    public let tag_name: String
    public let body: String
    public let assets: [Asset]

    public var modifiedBody: AttributedString {
        var result = AttributedString()
        let lines = body.components(separatedBy: .newlines)

        for line in lines {
            var attributedLine = AttributedString(line)

            /// Replace headers with bigger/bolder font
            /// Replace checkboxes, unchecked boxes and dashes with bullets
            
            if line.starts(with: "### ") {
                attributedLine = AttributedString(line.dropFirst(4))
                attributedLine.font = .system(size: 18, weight: .bold)
                attributedLine.foregroundColor = .primary
            } else if line.starts(with: "## ") {
                attributedLine = AttributedString(line.dropFirst(3))
                attributedLine.font = .system(size: 18, weight: .bold)
                attributedLine.foregroundColor = .primary
            } else if line.starts(with: "- []") {
                let checkboxReplaced = line.replacingOccurrences(of: "- []", with: "•")
                attributedLine = AttributedString(checkboxReplaced)
            } else if line.starts(with: "- [x]") {
                let checkboxReplaced = line.replacingOccurrences(of: "- [x]", with: "•")
                attributedLine = AttributedString(checkboxReplaced)
            } else {
                let checkboxReplaced = line.replacingOccurrences(of: "- ", with: "•")
                attributedLine = AttributedString(checkboxReplaced)
            }

            result.append(attributedLine)
            result.append(AttributedString("\n"))
        }

        return result
    }

}

struct ReleaseNotesView: View {
    let releaseNotes: AttributedString?

    var body: some View {
        ScrollView {
            Text(releaseNotes ?? "No release information")
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(20)
        }
    }
}

public struct Asset: Codable {
    public let name: String
    public let url: String
    public let browser_download_url: String
}

public enum UpdateFrequency: String, CaseIterable, Identifiable {
    case none = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    public var id: String { self.rawValue }

    public var interval: TimeInterval? {
        switch self {
        case .none:
            return nil
        case .daily:
            return 86400 // 1 day in seconds
        case .weekly:
            return 604800 // 7 days in seconds
        case .monthly:
            return 2592000 // 30 days in seconds
        }
    }

    public func updateNextUpdateDate() {
        guard let updateInterval = self.interval else { return }
        let newUpdateDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(updateInterval))
        UserDefaults.standard.set(newUpdateDate.timeIntervalSinceReferenceDate, forKey: "alinfoundation.updater.nextUpdateDate")
    }
}
