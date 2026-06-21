//
//  BytePatternSearchTests.swift
//  ediHexTests
//

import XCTest
@testable import ediHex

final class BytePatternSearchTests: XCTestCase {
    private func makeSequentialProvider() -> (Range<Int>) -> [UInt8] {
        { range in
            (range.lowerBound..<range.upperBound).map { UInt8($0 & 0xFF) }
        }
    }

    func testParseHexContinuous() {
        let result = BytePatternSearch.parseHex("DEADBEEF")
        guard case .success(let pattern) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(pattern, [0xDE, 0xAD, 0xBE, 0xEF])
    }

    func testParseHexSpaced() {
        let result = BytePatternSearch.parseHex("DE AD BE")
        guard case .success(let pattern) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(pattern, [0xDE, 0xAD, 0xBE])
    }

    func testParseHexPrefixedBytes() {
        let result = BytePatternSearch.parseHex("0xDE 0xAD")
        guard case .success(let pattern) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(pattern, [0xDE, 0xAD])
    }

    func testParseHexOddDigitCountRejected() {
        let result = BytePatternSearch.parseHex("DEA")
        guard case .failure(.oddDigitCount) = result else {
            return XCTFail("Expected oddDigitCount error")
        }
    }

    func testParseHexInvalidTokenRejected() {
        let result = BytePatternSearch.parseHex("GG")
        guard case .failure = result else {
            return XCTFail("Expected failure")
        }
    }

    func testParseHexEmptyRejected() {
        let result = BytePatternSearch.parseHex("   ")
        guard case .failure(.empty) = result else {
            return XCTFail("Expected empty error")
        }
    }

    func testASCIIPattern() {
        let result = BytePatternSearch.pattern(from: "hello", mode: .ascii)
        guard case .success(let pattern) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(pattern, Array("hello".utf8))
    }

    func testFindAllMultipleMatches() {
        let provider: (Range<Int>) -> [UInt8] = { _ in
            [0x01, 0x02, 0x01, 0x02, 0x01]
        }
        let matches = BytePatternSearch.findAll(pattern: [0x01, 0x02], in: 0..<5, bytesProvider: provider)
        XCTAssertEqual(matches, [0, 2])
    }

    func testSearchEntireFile() {
        let fileSize = 200
        let matches = BytePatternSearch.search(
            pattern: [0x01, 0x02],
            fileSize: fileSize,
            bytesProvider: makeSequentialProvider(),
            entireFile: true,
            direction: .down,
            cursor: 50
        )
        XCTAssertEqual(matches, [1])
    }

    func testSearchDownFromCursor() {
        let fileSize = 200
        let matches = BytePatternSearch.search(
            pattern: [0x32, 0x33],
            fileSize: fileSize,
            bytesProvider: makeSequentialProvider(),
            entireFile: false,
            direction: .down,
            cursor: 50
        )
        XCTAssertTrue(matches.allSatisfy { $0 >= 50 })
        XCTAssertEqual(matches.first, 50)
    }

    func testSearchUpFromCursor() {
        let fileSize = 200
        let matches = BytePatternSearch.search(
            pattern: [0x01, 0x02],
            fileSize: fileSize,
            bytesProvider: makeSequentialProvider(),
            entireFile: false,
            direction: .up,
            cursor: 50
        )
        XCTAssertEqual(matches, [1])
    }

    func testFindNextDown() {
        let data: [UInt8] = [0x01, 0x02, 0x00, 0x01, 0x02, 0x00, 0x01, 0x02]
        let provider: (Range<Int>) -> [UInt8] = { range in
            Array(data[range])
        }
        let next = BytePatternSearch.findNext(
            pattern: [0x01, 0x02],
            fileSize: data.count,
            bytesProvider: provider,
            entireFile: false,
            direction: .down,
            afterOffset: 1
        )
        XCTAssertEqual(next, 3)
    }

    func testFindNextUp() {
        let data: [UInt8] = [0x01, 0x02, 0x00, 0x01, 0x02, 0x00, 0x01, 0x02]
        let provider: (Range<Int>) -> [UInt8] = { range in
            Array(data[range])
        }
        let next = BytePatternSearch.findNext(
            pattern: [0x01, 0x02],
            fileSize: data.count,
            bytesProvider: provider,
            entireFile: false,
            direction: .up,
            afterOffset: 6
        )
        XCTAssertEqual(next, 3)
    }

    func testFormatMatchesEmpty() {
        XCTAssertEqual(BytePatternSearch.formatMatches([]), String(localized: "Not found"))
    }

    func testFormatMatchesMultiple() {
        let text = BytePatternSearch.formatMatches([16, 256])
        XCTAssertTrue(text.contains("0x"))
        XCTAssertTrue(text.contains("2 matches"))
    }

    func testParseHexTokensPatternOnly() {
        switch BytePatternSearch.parseHexTokens(["DEADBEEF"]) {
        case .success(let result):
            XCTAssertEqual(result.pattern, [0xDE, 0xAD, 0xBE, 0xEF])
            XCTAssertTrue(result.rangeTokens.isEmpty)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testParseASCIITokensPatternOnly() {
        let result = BytePatternSearch.parseASCIITokens(["dyld"], fileSize: 100)
        XCTAssertEqual(result?.pattern, Array("dyld".utf8))
        XCTAssertTrue(result?.rangeTokens.isEmpty ?? false)
    }

    func testParseASCIITokensWithRange() {
        let result = BytePatternSearch.parseASCIITokens(["dyld", "0", "end"], fileSize: 100)
        XCTAssertEqual(result?.pattern, Array("dyld".utf8))
        XCTAssertEqual(result?.rangeTokens, ["0", "end"])
    }

    func testParseASCIITokensFallsBackToFullPatternWhenRangeInvalid() {
        let result = BytePatternSearch.parseASCIITokens(["hello", "world"], fileSize: 100)
        XCTAssertEqual(result?.pattern, Array("hello world".utf8))
        XCTAssertTrue(result?.rangeTokens.isEmpty ?? false)
    }

    func testFindFirstReturnsEarly() {
        let fileSize = 1_000_000
        let chunkSize = 1_024
        var providerCalls = 0

        let provider: (Range<Int>) -> [UInt8] = { range in
            providerCalls += 1
            if range.lowerBound == 0 {
                return [0x01, 0x02]
            }
            return Array(repeating: 0x00, count: range.count)
        }

        let match = BytePatternSearch.findFirst(
            pattern: [0x01, 0x02],
            in: 0..<fileSize,
            bytesProvider: provider,
            chunkSize: chunkSize
        )

        XCTAssertEqual(match, 0)
        XCTAssertEqual(providerCalls, 1)
    }

    func testFindLast() {
        let data: [UInt8] = [0x01, 0x02, 0x00, 0x01, 0x02, 0x00, 0x01, 0x02]
        let provider: (Range<Int>) -> [UInt8] = { range in
            Array(data[range])
        }

        let last = BytePatternSearch.findLast(
            pattern: [0x01, 0x02],
            in: 0..<data.count,
            bytesProvider: provider
        )

        XCTAssertEqual(last, 6)
    }

    func testFindNextDoesNotScanEntireTail() {
        let fileSize = 1_000_000
        let chunkSize = 1_024
        var providerCalls = 0

        let provider: (Range<Int>) -> [UInt8] = { range in
            providerCalls += 1
            if range.lowerBound <= 2_048 {
                return [0x01, 0x02] + Array(repeating: 0x00, count: max(0, range.count - 2))
            }
            return Array(repeating: 0x00, count: range.count)
        }

        let next = BytePatternSearch.findNext(
            pattern: [0x01, 0x02],
            fileSize: fileSize,
            bytesProvider: provider,
            entireFile: false,
            direction: .down,
            afterOffset: 1_024
        )

        XCTAssertEqual(next, 1_025)
        XCTAssertLessThan(providerCalls, fileSize / chunkSize)
    }

    func testFindAllIncrementalReportsProgress() async {
        let fileSize = 200
        let provider = makeSequentialProvider()
        var progressValues: [Double] = []

        let matches = await BytePatternSearch.findAllIncremental(
            pattern: [0x01, 0x02],
            in: 0..<fileSize,
            bytesProvider: provider,
            chunkSize: 1_024,
            onProgress: { progress in
                progressValues.append(progress)
            },
            onMatch: nil
        )

        XCTAssertEqual(matches, [1])
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0)
    }
}
