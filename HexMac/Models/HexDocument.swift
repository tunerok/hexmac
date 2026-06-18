//
//  HexDocument.swift
//  HexMac
//

import Foundation

final class HexDocument {
    let url: URL
    let mappedFile: MemoryMappedFile

    var displayName: String {
        url.lastPathComponent
    }

    var fileSize: Int {
        mappedFile.size
    }

    var isOpen: Bool {
        fileSize >= 0
    }

    private(set) var isDirty = false

    init(url: URL, mappedFile: MemoryMappedFile) {
        self.url = url
        self.mappedFile = mappedFile
    }

    static func open(url: URL, readOnly: Bool = true) throws -> HexDocument {
        let mappedFile = try MemoryMappedFile.open(url: url, readOnly: readOnly)
        return HexDocument(url: url, mappedFile: mappedFile)
    }

    func markDirty() {
        isDirty = true
    }

    func markClean() {
        isDirty = false
    }

    func close() {
        mappedFile.close()
    }
}
