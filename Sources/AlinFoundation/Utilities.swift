//
//  Utilities.swift
//  
//
//  Created by Alin Lupascu on 7/10/24.
//

import Foundation
import SwiftUI
import OSLog
import AppKit
import CoreImage

//MARK: ====================================================== FUNCTIONS ======================================================


// Run shell commands

/// runShell("ls -al /") { output in
///   print(output)
/// }

public func runShell(_ command: String, completion: @escaping (String) -> Void) {
    // Create a new process
    let process = Process()
    // Set the executable to be used (assuming bash here, adjust as needed for your shell)
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    // Pass the command to be executed as an argument to the shell
    process.arguments = ["-c", command]

    // Create a pipe to read the output
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    // Start reading from the pipe asynchronously to get the output continuously
    let outHandle = pipe.fileHandleForReading
    outHandle.readabilityHandler = { fileHandle in
        // Convert the data read from the pipe into a string and pass it to the completion handler
        let data = fileHandle.availableData
        if let output = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                completion(output)
            }
        }
    }

    // Start the process
    do {
        try process.run()
        process.waitUntilExit() // Optionally wait for the process to complete
    } catch {
        DispatchQueue.main.async {
            completion("Failed to run command: \(error)")
        }
    }

    // Cleanup after the process completes
    process.terminationHandler = { _ in
        outHandle.readabilityHandler = nil
    }
}


// Execute apple scripts

/// let script = """
///   tell application "System Events"
///   get volume settings
///   end tell
///   """
///
/// runAppleScript(script) { result in
///    switch result {
///    case .success(let output):
///        print("AppleScript Output: \(output)")
///    case .failure(let error):
///        print("AppleScript Error: \(error)")
///    }
/// }

public func runAppleScript(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Create the AppleScript object from the command string
    if let script = NSAppleScript(source: command) {
        var errorDict: NSDictionary?
        // Execute the script
        let output = script.executeAndReturnError(&errorDict)

        // Check for errors and return the result
        if let error = errorDict as? [String: Any] {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "AppleScriptExecution", code: 0, userInfo: error)))
            }
        } else {
            let outputString = output.stringValue ?? "No output"
            DispatchQueue.main.async {
                completion(.success(outputString))
            }
        }
    } else {
        DispatchQueue.main.async {
            completion(.failure(NSError(domain: "AppleScriptCreation", code: 1, userInfo: ["NSLocalizedDescription": "Failed to create NSAppleScript object."])))
        }
    }
}


// Make updates on main thread
public func updateOnMain(after delay: Double? = nil, _ updates: @escaping () -> Void) {
    if let delay = delay {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            updates()
        }
    } else {
        DispatchQueue.main.async {
            updates()
        }
    }
}


// Execute functions on background thread
public func updateOnBackground(_ updates: @escaping () -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        updates()
    }
}

// Check if appearance is dark mode
public func isDarkMode() -> Bool {
    return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

// Set app color mode
public func setAppearance(mode: NSAppearance.Name) {
    NSApp.appearance = NSAppearance(named: mode)
}

// Check if app has any windows open
public func hasWindowOpen(title: String) -> Bool {
    for window in NSApp.windows where window.title == title {
        return true
    }
    return false
}

// Find and hide app windows via window title array
public func findAndHideWindows(named titles: [String]) {
    for title in titles {
        if let window = NSApp.windows.first(where: { $0.title == title }) {
            window.close()
        }
    }
}

// Find and show app windows via window title array
public func findAndShowWindows(named titles: [String]) {
    for title in titles {
        if let window = NSApp.windows.first(where: { $0.title == title }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// Copy to clipboard
public func copyToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

// Convert icon to png so colors render correctly
public func convertICNSToPNG(icon: NSImage, size: NSSize) -> NSImage? {
    // Resize the icon to the specified size
    let resizedIcon = NSImage(size: size)
    resizedIcon.lockFocus()
    icon.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
    resizedIcon.unlockFocus()

    // Convert the resized icon to PNG format
    if let resizedImageData = resizedIcon.tiffRepresentation,
       let resizedBitmap = NSBitmapImageRep(data: resizedImageData),
       let pngData = resizedBitmap.representation(using: .png, properties: [:]) {
        return NSImage(data: pngData)
    }

    return nil
}

// Get icon for files and folders
public func getIconForFileOrFolder(atPath path: URL) -> Image? {
    return Image(nsImage: NSWorkspace.shared.icon(forFile: path.path))
}

public func getIconForFileOrFolderNS(atPath path: URL) -> NSImage? {
    return NSWorkspace.shared.icon(forFile: path.path)
}



// Relaunch app
public func relaunchApp(afterDelay seconds: TimeInterval = 0.5) -> Never {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
    task.launch()

    NSApp.terminate(nil)
    exit(0)
}

// Check if macOS is specified version or higher
public func isVersionOrHigher(version: Int) -> Bool {
    let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
    return systemVersion.majorVersion >= version
}

// Check app directory and user's role
public func checkAppDirectoryAndUserRole(completion: @escaping ((isInCorrectDirectory: Bool, isAdmin: Bool)) -> Void) {
    isCurrentUserAdmin { isAdmin in
        let bundlePath = Bundle.main.bundlePath as NSString
        let applicationsDir = "/Applications"
        let userApplicationsDir = "\(NSHomeDirectory())/Applications"

        var isInCorrectDirectory = false

        if isAdmin {
            // Admins can have the app in either /Applications or ~/Applications
            isInCorrectDirectory = bundlePath.deletingLastPathComponent == applicationsDir ||
            bundlePath.deletingLastPathComponent == userApplicationsDir
        } else {
            // Standard users should only have the app in ~/Applications
            isInCorrectDirectory = bundlePath.deletingLastPathComponent == userApplicationsDir
        }

        // Return both conditions: if the app is in the correct directory and if the user is an admin
        completion((isInCorrectDirectory, isAdmin))
    }
}

// Check if user is admin
public func isCurrentUserAdmin(completion: @escaping (Bool) -> Void) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Using zsh, macOS default shell
    process.arguments = ["-c", "groups $(whoami) | grep -q ' admin '"]

    process.terminationHandler = { process in
        // On macOS, a process's exit status of 0 indicates success (admin group found in this context)
        completion(process.terminationStatus == 0)
    }

    do {
        try process.run()
    } catch {
        print("Failed to execute command: \(error)")
        completion(false)
    }
}

// --- Extend print command to also output to the Console ---
public func printOS(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    let log = OSLog(subsystem: Bundle.main.name, category: "Application")
    os_log("%@", log: log, type: .default, message)
}

// Get size of files
public func totalSizeOnDisk(for paths: [URL]) -> (real: Int64, logical: Int64) {
    let fileManager = FileManager.default
    var totalAllocatedSize: Int64 = 0
    var totalFileSize: Int64 = 0

    for url in paths {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey]
            if isDirectory.boolValue {
                // It's a directory, recurse into it
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, errorHandler: nil) {
                    for case let fileURL as URL in enumerator {
                        do {
                            let fileAttributes = try fileURL.resourceValues(forKeys: Set(keys))
                            if let allocatedSize = fileAttributes.totalFileAllocatedSize {
                                totalAllocatedSize += Int64(allocatedSize)
                            }
                            if let fileSize = fileAttributes.fileSize {
                                totalFileSize += Int64(fileSize)
                            }
                        } catch {
                            print("Error getting file attributes for \(fileURL): \(error)")
                        }
                    }
                }
            } else {
                // It's a file
                do {
                    let fileAttributes = try url.resourceValues(forKeys: Set(keys))
                    if let allocatedSize = fileAttributes.totalFileAllocatedSize {
                        totalAllocatedSize += Int64(allocatedSize)
                    }
                    if let fileSize = fileAttributes.fileSize {
                        totalFileSize += Int64(fileSize)
                    }
                } catch {
                    print("Error getting file attributes for \(url): \(error)")
                }
            }
        }
    }

    return (real: totalAllocatedSize, logical: totalFileSize)
}



public func totalSizeOnDisk(for path: URL) -> (real: Int64, logical: Int64) {
    return totalSizeOnDisk(for: [path])
}

// ByteFormatter
public func formatByte(size: Int64) -> (human: String, byte: String) {
    let byteCountFormatter = ByteCountFormatter()
    byteCountFormatter.countStyle = .file
    byteCountFormatter.allowedUnits = [.useAll]
    let human = byteCountFormatter.string(fromByteCount: size)

    let numberformatter = NumberFormatter()
    numberformatter.numberStyle = .decimal
    let formattedNumber = numberformatter.string(from: NSNumber(value: size)) ?? "\(size)"
    let byte = "\(formattedNumber)"

    return (human: human, byte: byte)

}

// Alert for Trash
public func showCustomAlert(enabled: Bool = true, title: String, message: String, style: NSAlert.Style, onOk: @escaping () -> Void) {
    if enabled {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style

        // Add "Okay" and "Cancel" buttons
        alert.addButton(withTitle: "Okay")
        alert.addButton(withTitle: "Cancel")

        // Present the alert and execute closure if "Okay" is pressed
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onOk()
        }
    } else {
        onOk()
    }
}

// Print callstack for troubleshooting
public func printCallStack(simple: Bool = true) {
    if simple {
        let callStack = Thread.callStackSymbols

        // Ensure there are at least 3 lines in the call stack
        guard callStack.count >= 3 else {
            print("Not enough call stack information available.")
            return
        }

        // Get the third line of the call stack
        let originLine = callStack[2]

        // Format and print the third call stack entry
        let components = originLine.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
        if components.count >= 5 {
            let _ = components[1] // module
            let _ = components[2] // address
            let functionInfo = components[3...4].joined(separator: " ")
            print("\nOrigin of the call:\n\n \(functionInfo)")
        } else {
            print("\nOrigin of the call:\n\n \(originLine)")
        }
    } else {
        Thread.callStackSymbols.forEach{print($0)}
    }
}

// Only process supported files
public func isSupportedFileType(at path: String) -> Bool {
    let fileManager = FileManager.default
    do {
        let attributes = try fileManager.attributesOfItem(atPath: path)
        if let fileType = attributes[FileAttributeKey.type] as? FileAttributeType {
            switch fileType {
            case .typeRegular, .typeDirectory, .typeSymbolicLink:
                // The file is a regular file, directory, or symbolic link
                return true
            default:
                // The file is a socket, pipe, or another type not supported
                return false
            }
        }
    } catch {
        printOS("Error getting file attributes: \(error)")
    }
    return false
}

// --- Create Application Support folder if it doesn't exist ---
public func ensureApplicationSupportFolderExists() {
    let fileManager = FileManager.default
    let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.name)

    // Check to make sure Application Support/App Name folder exists
    if !fileManager.fileExists(atPath: supportURL.path) {
        try! fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        printOS("Created Application Support/\(Bundle.main.name) folder")
    }
}


// --- Write Log to File for troubleshooting ---
public func writeLog(string: String) {
    let fileManager = FileManager.default
    let home = fileManager.homeDirectoryForCurrentUser.path
    let logFilePath = "\(home)/Downloads/log.txt"

    // Check if the log file exists, and create it if it doesn't
    if !fileManager.fileExists(atPath: logFilePath) {
        if !fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil) {
            printOS("Failed to create the log file.")
            return
        }
    }

    do {
        if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
            let ns = "\(string)\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(ns.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            printOS("Error opening file for appending")
        }
    }
}

// --- Get current timestamp ---
public func getCurrentTimestamp() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return dateFormatter.string(from: Date())
}

// --- Format date short style ---
public func formattedDate(_ date: Date = Date.now, dateStyle: DateFormatter.Style = .short, timeStyle: DateFormatter.Style = .none) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
    return formatter.string(from: date)
}

// --- Copy to clipboard ---
public func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}




//MARK: ====================================================== EXTENSIONS ======================================================




// --- Bundle extension ---
public extension Bundle {

    var name: String {
        func string(for key: String) -> String? {
            object(forInfoDictionaryKey: key) as? String
        }
        return string(for: "CFBundleDisplayName")
        ?? string(for: "CFBundleName")
        ?? "N/A"
    }

    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    var buildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var bundleId: String {
        self.bundleIdentifier ?? "N/A"
    }

}

// --- Extend Int to convert days to seconds ---
public extension Int {
    var daysToSeconds: Double {
        return Double(self) * 24 * 60 * 60
    }
}

// --- Capitalize first letter of string only
public extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

// --- Returns comma separated string as array of strings
public extension String {
    func toStringArray() -> [String] {
        if self.isEmpty {
            return []
        }
        return self.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// --- Overload the greater than operator ">" to do a semantic check on the string versions
public extension String {
    func versionStringToTuple() -> (Int, Int, Int) {
        let components = self.split(separator: ".").compactMap { Int($0) }
        return (
            components.count > 0 ? components[0] : 0,
            components.count > 1 ? components[1] : 0,
            components.count > 2 ? components[2] : 0
        )
    }

    static func > (lhs: String, rhs: String) -> Bool {
        let lhsVersion = lhs.versionStringToTuple()
        let rhsVersion = rhs.versionStringToTuple()
        return lhsVersion > rhsVersion
    }
}

// --- Trash Relationship ---
public extension FileManager {
    func isInTrash(_ file: URL) -> Bool {
        var relationship: URLRelationship = .other
        try? getRelationship(&relationship, of: .trashDirectory, in: .userDomainMask, toItemAt: file)
        return relationship == .contains
    }
}

// --- Extend string to replace - and | with custom characters
public extension String {
    func announcementFormat() -> String {
        return self.replacingOccurrences(of: "- ", with: "• ").replacingOccurrences(of: "|", with: "\n\n")
    }
}

// Get average color from image
public extension NSImage {
    var averageColor: NSColor? {
        guard let tiffData = self.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData), let inputImage = CIImage(bitmapImageRep: bitmapImage) else { return nil }

        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: CIFormat.RGBA8, colorSpace: nil)

        return NSColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

// Color extensions for theme manager
public extension Color {
    func adjustBrightness(_ percentage: CGFloat = 10.0, lighten: Bool = false) -> Color {
        let light = Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1)
        let dark  = Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1)
        let isDarkMode = ThemeManager.shared.displayMode.colorScheme == .dark
        let colorToModify: Color = self == .clear ? (isDarkMode ? dark : light) : self

        var hsb = (hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(0), alpha: CGFloat(0))
        NSColor(colorToModify).getHue(&hsb.hue, saturation: &hsb.saturation, brightness: &hsb.brightness, alpha: &hsb.alpha)

        let newBrightness = lighten ? min(hsb.brightness + percentage / 100, 1.0) : max(hsb.brightness - percentage / 100, 0)

        return Color(hue: hsb.hue, saturation: hsb.saturation, brightness: newBrightness, opacity: hsb.alpha)
    }
}


// UserDefaults extension for theme manager
public extension UserDefaults {
    func color(forKey key: String) -> Color? {
        guard let components = array(forKey: key) as? [CGFloat], components.count == 4 else {
            return nil
        }
        return Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }

    func setColor(_ color: Color, forKey key: String) {
        let nsColor = NSColor(color)
        if let components = nsColor.cgColor.components, components.count == 4 {
            set(components, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

// Color extensions for ColorPicker
public extension Color {
    func toHex() -> String {
        let uic = NSColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#FFFFFF"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let hexString = String(format: "#%02lx%02lx%02lx", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        return hexString
    }
}

public extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

public extension Color {
    func luminance(lightColor: Color = .black, darkColor: Color = .white) -> Color {
        if self == .clear {
            return Color.primary
        }
        let components = self.cgColor?.components
        let red = components?[0] ?? 0
        let green = components?[1] ?? 0
        let blue = components?[2] ?? 0

        // Calculate the relative luminance
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        // Use a threshold to determine if the color is bright or dark
        return luminance > 0.65 ? lightColor : darkColor
    }
}

public extension Color {
    func luminanceDisplayMode() {
        let themeManager = ThemeManager.shared
        let components = self.cgColor?.components
        let red = components?[0] ?? 0
        let green = components?[1] ?? 0
        let blue = components?[2] ?? 0

        // Calculate the relative luminance
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        // Use a threshold to determine if the color is bright or dark
        if luminance > 0.65 {
            themeManager.displayMode = .light
        } else {
            themeManager.displayMode = .dark
        }
    }
}

// Hex string to Color
public extension String {
    func hexToColor() -> Color {
        var hex = self.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6, let intCode = Int(hex, radix: 16) else {
            return Color.clear
        }
        let red = Double((intCode >> 16) & 0xFF) / 255.0
        let green = Double((intCode >> 8) & 0xFF) / 255.0
        let blue = Double(intCode & 0xFF) / 255.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}


// Check if a URL path is a symlink
extension URL {
    public func isSymlink() -> Bool {
        do {
            let _ = try self.checkResourceIsReachable()
            let resourceValues = try self.resourceValues(forKeys: [.isSymbolicLinkKey])
            return resourceValues.isSymbolicLink == true
        } catch {
            return false
        }
    }
}
