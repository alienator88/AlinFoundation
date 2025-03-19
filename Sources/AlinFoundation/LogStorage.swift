//
//  LogStorage.swift
//  AlinFoundation
//
//  Created by Alin Lupascu on 3/19/25.
//
import Foundation
import SwiftUI
import OSLog

// --- Extend print command to also output to the Console and optional LogStorage via Logger ---

public struct LogCategory {
    public static let general = "General"
    public static let appLoad = "AppLoad"
    public static let ui = "UI"
    public static let updater = "Updater"
    public static let fileSearch = "FileSearch"
    public static let orphanedFileSearch = "OrphanedFileSearch"
}

public class LogStorage: ObservableObject {
    public static let shared = LogStorage()
    @Published public var logs: [String] = []

    public init() {}

    public func addLog(_ message: String) {
        updateOnMain {
            self.logs.append(message)
            if self.logs.count > 50 {
                self.logs.removeFirst(self.logs.count - 50) // Keep only the last 50 logs
            }
        }
    }

    public func clearLogs() {
        updateOnMain {
            self.logs.removeAll()
        }
    }
}

public func printOS(_ items: Any..., separator: String = " ", category: String = LogCategory.general, logType: OSLogType = .error) {
    let message = items.map { "\($0)" }.joined(separator: separator)
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.alienator88.fallback", category: category)
    logger.log(level: logType, "\(message, privacy: .public)")
    Swift.print(message)
    // Store the log message in memory if LogStorage is initialized
    if LogStorage.shared != nil {
        let formatter = DateFormatter()
        formatter.dateFormat = "[MMM d, h:mm:ss a]"
        let timestamp = formatter.string(from: Date())
        let datedMessage = "\(timestamp) \(message)"
        LogStorage.shared.addLog(datedMessage)
    }
}

public struct ConsoleView: View {
    @ObservedObject private var logStorage = LogStorage.shared
    @State private var showCopy: Bool = false

    public init() {}

    public var body: some View {

        ZStack {

            VStack(alignment: .center, spacing: 0) {

                ZStack {
                    Text("Console Logs")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Spacer()

                        Button(action: {
                            let allLogs = logStorage.logs.joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(allLogs, forType: .string)
                            showCopy = true
                            updateOnMain(after: 2) {
                                showCopy = false
                            }
                        }) {
                            Image(systemName: "doc.on.doc")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .padding(5)
                        }
                        .help("Copy all logs")
                        .disabled(logStorage.logs.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                        Button(action: {
                            logStorage.clearLogs()
                        }) {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .padding(5)
                        }
                        .help("Clear all logs")
                        .disabled(logStorage.logs.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding()


                if logStorage.logs.isEmpty {
                    Text("No logs available to view")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(logStorage.logs.indices, id: \.self) { index in
                        HStack {
                            Text(logStorage.logs[index])
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(5)
                                .onTapGesture {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(logStorage.logs[index], forType: .string)
                                    showCopy = true
                                    updateOnMain(after: 2, {
                                        showCopy = false
                                    })
                                }
                        }

                    }
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom])
                }

                if !logStorage.logs.isEmpty {
                    Text("Click a log line to individually copy")
                        .font(.callout)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.bottom)
                }

            }

            if showCopy {
                Image(systemName: "checkmark")
                    .font(.system(size: 30))
                    .foregroundStyle(.green)
                    .padding()
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.1))
                    }
            }
        }

        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
    }
}
