//
//  FileAccessService.swift
//  HexMac
//

import AppKit
import UniformTypeIdentifiers

enum FileAccessService {
    @MainActor
    static func openFilePanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        panel.allowedContentTypes = [.data, .item, .content]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url
    }

    @MainActor
    static func saveFilePanel(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.data]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url
    }
}
