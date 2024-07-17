//
//  TokenManager.swift
//
//
//  Created by Alin Lupascu on 7/11/24.
//

import Foundation

public class TokenManager {

    private let service: String
    private let account: String
    private let repoUser: String
    private let repoName: String
    private let repoURL: String

    public init(name: String, account: String? = nil, repoUser: String, repoName: String) {
        self.service = name
        self.account = account ?? NSFullUserName()
        self.repoUser = repoUser ?? ""
        self.repoName = repoName ?? ""
        self.repoURL = "https://api.github.com/repos/\(repoUser)/\(repoName)"
    }

    public func saveToken(_ token: String, completion: @escaping (Bool) -> Void) {
        guard !token.isEmpty else {
            completion(false)
            return
        }
        let data = Data(token.utf8)
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ] as CFDictionary

        // Remove any existing token
        SecItemDelete(query)

        // Attempt to save the new token
        let status = SecItemAdd(query, nil)
        DispatchQueue.main.async {
            if status == noErr {
                completion(true)
            } else {
                print("Error saving token to Keychain: \(status)")
                completion(false)
            }
        }
    }

    public func loadToken(completion: @escaping (Bool) -> Void) -> String {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        if status == noErr, let data = result as? Data, let token = String(data: data, encoding: .utf8) {
            completion(true)
            return token
        } else {
            print("Error retrieving token from Keychain: \(status)")
            completion(false)
            return ""
        }
    }

    public func deleteToken(completion: @escaping (Bool) -> Void) {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary

        let status = SecItemDelete(query)
        if status != noErr {
            print("Error deleting token from Keychain: \(status)")
            completion(false)
        } else {
            completion(true)
        }
    }

    public func checkTokenValidity(token: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: repoURL) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")


        URLSession.shared.dataTask(with: request) { _, response, error in
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }

            if httpResponse.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
}
