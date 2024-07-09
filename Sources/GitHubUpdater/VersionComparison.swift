//
//  VersionComparison.swift
//  
//
//  Created by Alin Lupascu on 7/8/24.
//

// VersionComparison.swift

import Foundation

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


extension Bundle {

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

}
