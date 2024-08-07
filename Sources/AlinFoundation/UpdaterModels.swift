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

    public func modifiedBody(owner: String, repo: String) -> NSAttributedString? {
        let result = NSMutableAttributedString()
        let lines = body.components(separatedBy: .newlines)

        for line in lines {
            let attributedLine = handlePattern(line: line, owner: owner, repo: repo)
            result.append(attributedLine)
            result.append(NSAttributedString(string: "\n"))
        }

        return result
    }

    // Function to handle each pattern
    private func handlePattern(line: String, owner: String, repo: String) -> NSMutableAttributedString {
        let attributedLine = NSMutableAttributedString(string: line)

        // Check for headers and apply styles
        if line.starts(with: "### ") {
            return headerAttributedString(from: line.dropFirst(4), size: 18)
        } else if line.starts(with: "## ") {
            return headerAttributedString(from: line.dropFirst(3), size: 18)
        }

        // Replace checkboxes and bullet points
        if line.contains("- []") {
            let replaced = line.replacingOccurrences(of: "- []", with: "•")
            attributedLine.mutableString.setString(replaced)
        }

        if line.contains("- [x]") {
            let replaced = line.replacingOccurrences(of: "- [x]", with: "•")
            attributedLine.mutableString.setString(replaced)
        }

        // Handle issue numbers and make them clickable
        let regex = try! NSRegularExpression(pattern: "#(\\d+)")
        let range = NSRange(line.startIndex..., in: line)

        // Find and replace issue numbers with clickable links
        for match in regex.matches(in: line, options: [], range: range) {
            if let issueNumberRange = Range(match.range(at: 1), in: line) {
                let issueNumber = line[issueNumberRange]
                let issueURL = "https://github.com/\(owner)/\(repo)/issues/\(issueNumber)"

                // Create the clickable link using the extension
                let fullIssueNumber = "#\(issueNumber)"
                attributedLine.setAsLink(textToFind: fullIssueNumber, linkURL: issueURL)

                // Optional: Change the color to indicate it's a link
                let linkRange = (attributedLine.string as NSString).range(of: fullIssueNumber)
//                attributedLine.addAttribute(.foregroundColor, value: NSColor.blue, range: linkRange)
                attributedLine.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            }
        }

        return attributedLine
    }

    private func headerAttributedString(from line: Substring, size: CGFloat) -> NSMutableAttributedString {
        let attributedLine = NSMutableAttributedString(string: String(line))
        attributedLine.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: NSRange(location: 0, length: attributedLine.length))
//        attributedLine.addAttribute(.foregroundColor, value: NSColor.black, range: NSRange(location: 0, length: attributedLine.length))
        return attributedLine
    }

    

}

extension NSMutableAttributedString {

    public func setAsLink(textToFind:String, linkURL:String) -> Bool {

        let foundRange = self.mutableString.range(of: textToFind)
        if foundRange.location != NSNotFound {
            self.addAttribute(.link, value: linkURL, range: foundRange)
            return true
        }
        return false
    }
}

struct ReleaseNotesView: View {
    let release: Release?
    let owner: String
    let repo: String

    var body: some View {
        ScrollView {
            if let release = release,
               let releaseNotes = release.modifiedBody(owner: owner, repo: repo) {
                Text(AttributedString(releaseNotes))
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(20)
                    .textSelection(.disabled)
            } else {
                Text("No release information")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(20)
            }
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
