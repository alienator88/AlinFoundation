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
    public let tagName: String
    public let name: String
    public let body: String
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case assets
    }

    public static let issueRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "#(\\d+)")

    public func modifiedBody(owner: String, repo: String) -> NSAttributedString? {
        let pattern = #"!\[.*?\]\((.*?)\)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        var resolvedURLs: [URL] = []

        if let regex = regex {
            let matches = regex.matches(in: body, range: NSRange(body.startIndex..., in: body))
            for match in matches {
                if let range = Range(match.range(at: 1), in: body),
                   let initialURL = URL(string: String(body[range])) {
                    let semaphore = DispatchSemaphore(value: 0)
                    let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
                    var finalURL: URL?
                    let task = session.dataTask(with: initialURL) { _, response, _ in
                        finalURL = response?.url
                        semaphore.signal()
                    }
                    task.resume()
                    semaphore.wait()
                    if let finalURL = finalURL {
                        resolvedURLs.append(finalURL)
                    }
                }
            }
        }

        ImageURLCollector.shared.urls = resolvedURLs

        let cleanedBody = body.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        let lines = cleanedBody.components(separatedBy: .newlines)

        let result = NSMutableAttributedString()

        for line in lines {
            if !line.isEmpty {
                let attributedLine = handlePattern(line: line, owner: owner, repo: repo)
                result.append(attributedLine)
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private func handlePattern(line: String, owner: String, repo: String) -> NSMutableAttributedString {
        let attributedLine = NSMutableAttributedString(string: line)

        // Check for headers and apply styles
        if line.starts(with: "### ") || line.starts(with: "## ") || line.starts(with: "# ") {
            let headerLevel = line.prefix(while: { $0 == "#" }).count
            let text = line.replacingOccurrences(of: String(repeating: "#", count: headerLevel) + " ", with: "")
            return headerAttributedString(from: text, size: 18)
        }

        // Replace checkboxes and bullet points
        if line.contains("- [ ]") || line.contains("- [x]") {
            let replaced = line.replacingOccurrences(of: "- [x]", with: "•")
                .replacingOccurrences(of: "- [ ]", with: "•")
            attributedLine.mutableString.setString(replaced)
        }

        // Handle issue numbers and make them clickable
        guard let regex = Release.issueRegex else {
            return attributedLine
        }
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
                attributedLine.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            }
        }

        return attributedLine
    }

    private func headerAttributedString(from line: String, size: CGFloat) -> NSMutableAttributedString {
        let attributedLine = NSMutableAttributedString(string: line)
        attributedLine.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: NSRange(location: 0, length: attributedLine.length))
        attributedLine.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributedLine.length))

        let newLine = NSMutableAttributedString(string: "\n")
        attributedLine.append(newLine)

        return attributedLine
    }
}

extension NSMutableAttributedString {
    public func setAsLink(textToFind: String, linkURL: String) {
        let fullText = self.string
        var searchRange = fullText.startIndex..<fullText.endIndex
        while let foundRange = fullText.range(of: textToFind, options: .caseInsensitive, range: searchRange) {
            let nsRange = NSRange(foundRange, in: fullText)
            self.addAttribute(.link, value: linkURL, range: nsRange)
            searchRange = foundRange.upperBound..<fullText.endIndex
        }
    }
}

// Sheet update release notes view for single update
struct SingleReleaseNotesView: View {
    @StateObject private var collector = ImageURLCollector()
    let release: Release?
    let owner: String
    let repo: String

    var body: some View {
        ScrollView {
            if let release = release,
               let releaseNotes = release.modifiedBody(owner: owner, repo: repo) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(AttributedString(releaseNotes))
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .textSelection(.disabled)

                    ReleaseImagesView(markdown: release.body)
                }
                .frame(width: .infinity)
                .padding()
                .onAppear {
                    collector.reset()
                    collector.collect(from: release.body)
                }
            } else {
                Text("No release information")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(20)
            }
        }
    }
}

class ImageURLCollector: ObservableObject {
    static let shared = ImageURLCollector()
    @Published var urls: [URL] = []

    func reset() {
        urls = []
    }

    func collect(from markdown: String) {
        let pattern = #"!\[.*?\]\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(in: markdown, range: NSRange(markdown.startIndex..., in: markdown))

        for match in matches {
            if let range = Range(match.range(at: 1), in: markdown),
               let initialURL = URL(string: String(markdown[range])) {
                Task {
                    if let resolvedURL = await initialURL.resolvedRedirect() {
                        DispatchQueue.main.async {
                            self.urls.append(resolvedURL)
                        }
                    }
                }
            }
        }
    }
}

public struct Asset: Codable {
    public let name: String
    public let url: String
    public let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case url
        case browserDownloadURL = "browser_download_url"
    }
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
        UserDefaults.standard.set(newUpdateDate.timeIntervalSinceReferenceDate, forKey: DefaultsKeys.nextUpdateDate)
    }
}

//MARK: https://jonathandionne.com/posts/swift-snippet-url-resolver/
extension URL {
    func resolvedRedirect() async -> URL? {
        await withCheckedContinuation { continuation in
            var request = URLRequest(url: self)
            request.httpMethod = "HEAD"
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("keep-alive", forHTTPHeaderField: "Connection")
            request.setValue(self.host, forHTTPHeaderField: "Host")

            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                guard let httpResponse = response as? HTTPURLResponse, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                if let location = httpResponse.value(forHTTPHeaderField: "Location"),
                   let redirectedURL = URL(string: location) {
                    continuation.resume(returning: redirectedURL)
                } else {
                    continuation.resume(returning: httpResponse.url)
                }
            }
            task.resume()
        }
    }
}
