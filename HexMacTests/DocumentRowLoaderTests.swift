//
//  DocumentRowLoaderTests.swift
//  HexMacTests
//

import Foundation
import Testing
@testable import HexMac

struct DocumentRowLoaderTests {
    @Test func batchLoadSplitsRows() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let payload = Data((0..<48).map { UInt8($0) })
        try payload.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let file = try FileReference.open(url: tempURL, readOnly: true)
        let array = BTreeByteArray.fromFile(file)

        let rows = DocumentRowLoader.loadRows(
            for: 0..<3,
            bytesPerRow: 16,
            fileSize: 48,
            byteArray: array
        )

        #expect(rows.count == 3)
        #expect(rows[0] == Array(0..<16))
        #expect(rows[1] == Array(16..<32))
        #expect(rows[2] == Array(32..<48))
    }
}
