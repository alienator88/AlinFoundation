//
//  Authorization.swift
//
//
//  Created by Alin Lupascu on 7/10/24.
//


import Foundation
import Swift

//MARK: How to run function
//  let (success, output) = performPrivilegedCommands(commands: "")

public func performPrivilegedCommands(commands: String) -> (Bool, String) {
    var authRef: AuthorizationRef!
    var status = AuthorizationCreate(nil, nil, [], &authRef)
    guard status == errAuthorizationSuccess else { return (false, "Authorization creation failed with code \(status)") }
    defer { AuthorizationFree(authRef, [.destroyRights]) }
    
    var item = kAuthorizationRightExecute.withCString { name in
        AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
    }
    var rights = withUnsafeMutablePointer(to: &item) { ptr in
        AuthorizationRights(count: 1, items: ptr)
    }
    status = AuthorizationCopyRights(authRef, &rights, nil, [.interactionAllowed, .preAuthorize, .extendRights], nil)
    guard status == errAuthorizationSuccess else { return (false, "Authorization copy rights failed with code \(status)") }
    
    let (execStatus, output) = executeWithPrivileges(authorization: authRef, cmd: "/bin/sh", arguments: ["-c", commands])
    return (execStatus == errAuthorizationSuccess, output)
}

public func executeWithPrivileges(authorization: AuthorizationRef, cmd: String, arguments: [String]) -> (OSStatus, String) {
    let RTLD_DEFAULT = dlopen(nil, RTLD_NOW)
    guard let funcPtr = dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges") else {
        return (-1, "Failed to find AuthorizationExecuteWithPrivileges")
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
        UnsafePointer<CChar>,
        AuthorizationFlags,
        UnsafePointer<UnsafeMutablePointer<CChar>?>,
        UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>
    ) -> OSStatus
    
    let impl = unsafeBitCast(funcPtr, to: AuthorizationExecuteWithPrivilegesImpl.self)
    
    var filePointer: UnsafeMutablePointer<FILE>? = nil
    let status = impl(authorization, cmd, [], argPtrs, &filePointer)
    
    var output: String = ""
    if let fp = filePointer {
        let fd = fileno(fp)
        let fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        let data = fileHandle.readDataToEndOfFile()
        output = String(data: data, encoding: .utf8) ?? ""
        fclose(fp)
    }
    
    return (status, output)
}
