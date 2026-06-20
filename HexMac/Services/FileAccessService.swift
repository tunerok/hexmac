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
    static func createNewFile() throws -> URL? {
        guard let url = saveFilePanel(suggestedName: "Untitled.bin") else { return nil }
        try Data([0x00]).write(to: url)
        return url
    }

    @MainActor
    static func saveFilePanel(suggestedName: String, fileExtension: String? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        if let fileExtension {
            panel.allowedContentTypes = [contentType(for: fileExtension)]
        } else {
            panel.allowedContentTypes = [.data]
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url
    }

    private static func contentType(for fileExtension: String) -> UTType {
        UTType(filenameExtension: fileExtension) ?? .data
    }
}
