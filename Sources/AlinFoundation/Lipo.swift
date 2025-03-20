//
//  Lipo.swift
//  AlinFoundation
//
//  Created by Alin Lupascu on 3/20/25.
//

import Foundation
import AlinFoundation

// Helper structs for Mach-O parsing
public struct FatHeader {
    let magic: UInt32
    let numArchitectures: UInt32

    public init(magic: UInt32, numArchitectures: UInt32) {
        self.magic = magic
        self.numArchitectures = numArchitectures
    }
}

public struct FatArch {
    let cpuType: UInt32
    let cpuSubtype: UInt32
    let offset: UInt32
    let size: UInt32
    let align: UInt32

    public init(cpuType: UInt32, cpuSubtype: UInt32, offset: UInt32, size: UInt32, align: UInt32) {
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.offset = offset
        self.size = size
        self.align = align
    }
}

// Helper function to thin a binary using Mach-O APIs
public func thinBinaryUsingMachO(executablePath: String) -> Bool {
    // Determine the target architecture based on the current OS
    let targetArch = isOSArm() ? "arm64" : "x86_64"
    // Determine app bundle path
    let executableURL = URL(fileURLWithPath: executablePath)
    let appBundlePath = executableURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    do {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: executablePath))

        // Check if file is a fat binary
        let FAT_MAGIC: UInt32 = 0xcafebabe
        let fatHeader = fileData.subdata(in: 0..<8).withUnsafeBytes { ptr in
            FatHeader(
                magic: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                numArchitectures: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
            )
        }

        guard fatHeader.magic == FAT_MAGIC else {
            printOS("Mach-O Error: Not a universal binary, skipping thinning.")
            return false
        }

        var offset = 8
        var foundArch: FatArch?

        for _ in 0..<fatHeader.numArchitectures {
            let archData = fileData.subdata(in: offset..<(offset + 20)).withUnsafeBytes { ptr in
                FatArch(
                    cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                    cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                    offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                    size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                    align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                )
            }

            let cpuType = archData.cpuType
            if (targetArch == "arm64" && cpuType == 0x100000C) || (targetArch == "x86_64" && cpuType == 0x01000007) {
                foundArch = archData
                break
            }

            offset += 20
        }

        guard let targetArchData = foundArch else {
            printOS("Mach-O Error: Target architecture \(targetArch) not found in binary.")
            return false
        }

        let extractedData = fileData.subdata(in: Int(targetArchData.offset)..<Int(targetArchData.offset + targetArchData.size))
        try extractedData.write(to: URL(fileURLWithPath: executablePath))

        // Update file timestamp to refresh Finder bundle size right away
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: appBundlePath.path)

        return true

    } catch {
        printOS("Mach-O Error: \(error)")
        return false
    }
}
