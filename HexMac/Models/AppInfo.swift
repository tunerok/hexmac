//
//  AppInfo.swift
//  HexMac
//

import Foundation

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1b"
    }

    static let name = "HexMac"
}
