//
//  Authorization.swift
//
//
//  Created by Alin Lupascu on 7/10/24.
//


import Foundation
import Swift

//MARK: How to run function
//  let success = performPrivilegedCommands(commands: "")

public func performPrivilegedCommands(commands: String) -> Bool {
    var authRef: AuthorizationRef!
    var status = AuthorizationCreate(nil, nil, [], &authRef)
    guard status == errAuthorizationSuccess else { return false }
    defer { AuthorizationFree(authRef, [.destroyRights]) }

    var item = kAuthorizationRightExecute.withCString { name in
        AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
    }
    var rights = withUnsafeMutablePointer(to: &item) { ptr in
        AuthorizationRights(count: 1, items: ptr)
    }
    status = AuthorizationCopyRights(authRef, &rights, nil, [.interactionAllowed, .preAuthorize, .extendRights], nil)
    guard status == errAuthorizationSuccess else { return false }

    status = executeWithPrivileges(authorization: authRef, cmd: "/bin/sh", arguments: ["-c", commands])

    return status == errAuthorizationSuccess
}


public func executeWithPrivileges(authorization: AuthorizationRef, cmd: String, arguments: [String]) -> OSStatus {
    let RTLD_DEFAULT = dlopen(nil, RTLD_NOW)
    guard let funcPtr = dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges") else {
        printOS("Failed to find AuthorizationExecuteWithPrivileges")
        return -1
    }

    var argPtrs: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
    argPtrs.append(nil)
    defer {
        for ptr in argPtrs.dropLast() {
            if let ptr = ptr { free(ptr) }
        }
    }

    typealias AuthorizationExecuteWithPrivilegesImpl = @convention(c) (
        AuthorizationRef,
        UnsafePointer<CChar>, // cmd path
        AuthorizationFlags,
        UnsafePointer<UnsafeMutablePointer<CChar>?>, // cmd arguments
        UnsafeMutablePointer<UnsafeMutablePointer<FILE>>?
    ) -> OSStatus

    let impl = unsafeBitCast(funcPtr, to: AuthorizationExecuteWithPrivilegesImpl.self)

    return impl(authorization, cmd, [], argPtrs, nil)
}



// https://github.com/x13a/authorization-swift

//MARK: Execute a shell command with sudo privileges request
/// func runCommand() throws {
///   let fileHandler = try Authorization.executeWithPrivileges("/bin/ls /").get()
///   print(String(bytes: fileHandler.readDataToEndOfFile(), encoding: .utf8)!)
/// }

//public struct Authorization {
//
//    public enum Error: Swift.Error {
//        case create(OSStatus)
//        case copyRights(OSStatus)
//        case exec(OSStatus)
//    }
//
//    public static func executeWithPrivileges(_ command: String) -> Result<FileHandle, Error> {
//
//        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
//        var fn: @convention(c) (
//            AuthorizationRef,
//            UnsafePointer<CChar>,  // path
//            AuthorizationFlags,
//            UnsafePointer<UnsafePointer<CChar>?>,  // args
//            UnsafeMutablePointer<UnsafeMutablePointer<FILE>>?
//        ) -> OSStatus
//        fn = unsafeBitCast(
//            dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges"),
//            to: type(of: fn)
//        )
//
//        var authorizationRef: AuthorizationRef? = nil
//        var err = AuthorizationCreate(nil, nil, [], &authorizationRef)
//        guard err == errAuthorizationSuccess else {
//            return .failure(.create(err))
//        }
//        defer { AuthorizationFree(authorizationRef!, [.destroyRights]) }
//
//        var components = command.components(separatedBy: " ")
//        var path = components.remove(at: 0).cString(using: .utf8)!
//        let name = kAuthorizationRightExecute.cString(using: .utf8)!
//
//        var items: AuthorizationItem = name.withUnsafeBufferPointer { nameBuf in
//            path.withUnsafeBufferPointer { pathBuf in
//                let pathPtr =
//                UnsafeMutableRawPointer(mutating: pathBuf.baseAddress!)
//                return AuthorizationItem(
//                    name: nameBuf.baseAddress!,
//                    valueLength: path.count,
//                    value: pathPtr,
//                    flags: 0
//                )
//            }
//        }
//
//        var rights: AuthorizationRights =
//        withUnsafeMutablePointer(to: &items) { items in
//            return AuthorizationRights(count: 1, items: items)
//        }
//
//        let flags: AuthorizationFlags = [
//            .interactionAllowed,
//            .preAuthorize,
//            .extendRights,
//        ]
//
//        err = AuthorizationCopyRights(
//            authorizationRef!,
//            &rights,
//            nil,
//            flags,
//            nil
//        )
//        guard err == errAuthorizationSuccess else {
//            return .failure(.copyRights(err))
//        }
//
//        let rest = components.map { $0.cString(using: .utf8)! }
//        var args = Array<UnsafePointer<CChar>?>(
//            repeating: nil,
//            count: rest.count + 1
//        )
//        for (idx, arg) in rest.enumerated() {
//            args[idx] = UnsafePointer<CChar>?(arg)
//        }
//
//        var file = FILE()
//        let fh: FileHandle?
//
//        (err, fh) = withUnsafeMutablePointer(to: &file) { file in
//            var pipe = file
//            let err = fn(authorizationRef!, &path, [], &args, &pipe)
//            guard err == errAuthorizationSuccess else {
//                return (err, nil)
//            }
//            let fh = FileHandle(
//                fileDescriptor: fileno(pipe),
//                closeOnDealloc: true
//            )
//            return (err, fh)
//        }
//        guard err == errAuthorizationSuccess else {
//            return .failure(.exec(err))
//        }
//        return .success(fh!)
//    }
//}

