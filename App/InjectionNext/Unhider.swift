//
//  Unhider.swift
//  InjectionNext
//
//  Created by John H on 11/06/2024.
//  Copyright © 2024 John Holdsworth. All rights reserved.
//
//  In Swift "default argument generators" are emitted "private external"
//  which means you can link against them but not dynamic link against them.
//  This code exports these symbols in all object files in the derived data
//  of a project so code which uses a default argument is able to inject.
//
import Foundation
import SwiftRegex
import Fortify
import DLKit
import Popen

open class Unhider {
    
    static var packageFrameworks: String?
    static let unhideQueue = DispatchQueue(label: "Unhider")
    static var lastUnhidden = [String: Date]()
    
    open class func log(_ msg: String) {
        InjectionServer.currentClient?.log(msg)
    }
    
    open class func startUnhide() {
        guard var derivedData = packageFrameworks.flatMap({
            URL(fileURLWithPath: $0) }) else {
            log("⚠️ packageFrameworks not set")
            return
        }
        for _ in 1...5 {
            derivedData = derivedData.deletingLastPathComponent()
        }
        let intermediates = derivedData
            .appendingPathComponent("Build/Intermediates.noindex")
        unhideQueue.sync {
            do {
                try Fortify.protect {
                    log("Starting \"unhide\" for "+intermediates.path+"...")
                    var unhidden = Set<String>(), files = 0
                    let enumerator = FileManager.default
                        .enumerator(atPath: intermediates.path)
                    while let path = enumerator?.nextObject() as? String {
                        guard path.hasSuffix(".o") else { continue }
                        unhide(object: intermediates
                            .appendingPathComponent(path).path, &unhidden)
                        files += 1
                    }
                    log("""
                        Exported \(unhidden.count) symbols in \
                        \(files) files, please restart your app.
                        """)
                }
            } catch {
                log("⚠️ Unhide error: \(error)")
            }
        }
    }
    
    open class func unhide(object path: String, _ unhidden: inout Set<String>) {
        guard let object = FileSymbols(path: path) else {
            log("⚠️ Could not load "+path)
            return
        }

        var patched = 0, global: UInt8 = 0xf
        for entry in object.entries.filter({
            $0.entry.pointee.n_type & UInt8(N_PEXT) != 0 &&
            $0.symbol[#"A\d*_$"#] && unhidden.insert($0.symbol).inserted }) {
            entry.entry.pointee.n_type = global
            entry.entry.pointee.n_desc = UInt16(N_GSYM)
            patched += 1
        }

        if patched != 0 {
            if !object.save(to: path) {
                log("⚠️ Could not save "+path)
            } else if let stat = Fstat(path: path) {
                lastUnhidden[path] = stat.modified
            }
        }
    }
    
    open class func reunhide() -> Bool {
        var exported = false
        unhideQueue.sync {
            var unhidden = Set<String>()
            for (path, when) in lastUnhidden {
                if Fstat(path: path)?.modified != when {
                    unhide(object: path, &unhidden)
                    log("Re-exported "+URL(fileURLWithPath: path)
                        .lastPathComponent+", restart your app.")
                    exported = true
                }
            }
        }
        return exported
    }
}
