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
    static let author = "tunerok(Artem Ashirov)"
    static let copyrightYear = "2026"
    static let repositoryURL = URL(string: "https://github.com/tunerok/hexmac")!
}
