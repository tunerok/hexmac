//
//  TerminalCommandParserTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class TerminalRangeSpecTests: XCTestCase {
    func testSingleDecimalRange() {
        let spec = try? TerminalRangeSpec.parse(positionalTokens: ["0", "100"], fileSize: 200).get()
        XCTAssertEqual(spec?.segments, [0..<101])
    }

    func testSingleHexRange() {
        let spec = try? TerminalRangeSpec.parse(positionalTokens: ["0x0", "0xFF"], fileSize: 256).get()
        XCTAssertEqual(spec?.segments, [0..<256])
    }

    func testMixedDecimalAndHex() {
        let spec = try? TerminalRangeSpec.parse(positionalTokens: ["0", "0xFF"], fileSize: 256).get()
        XCTAssertEqual(spec?.segments, [0..<256])
    }

    func testMultiSegmentRange() {
        let spec = try? TerminalRangeSpec.parse(positionalTokens: ["0", "255,", "512", "767"], fileSize: 1000).get()
        XCTAssertEqual(spec?.segments, [0..<256, 512..<768])
    }

    func testReversedEndpoints() {
        let spec = try? TerminalRangeSpec.parse(positionalTokens: ["100", "0"], fileSize: 200).get()
        XCTAssertEqual(spec?.segments, [0..<101])
    }

    func testOutOfBoundsRejected() {
        let result = TerminalRangeSpec.parse(positionalTokens: ["0", "300"], fileSize: 200)
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure")
        }
        XCTAssertTrue(error.message.contains("300"))
        XCTAssertTrue(error.message.contains("200"))
    }
}

final class TerminalByteSamplerTests: XCTestCase {
    func testMaskFilter() {
        let flags = TerminalSamplingFlags(every: nil, mask: 0xF0, eq: nil)
        let result = TerminalByteSampler.apply(flags: flags, to: [0x01, 0xA0, 0x05, 0xB0])
        XCTAssertEqual(result, [0xA0, 0xB0])
    }

    func testMaskWithEq() {
        let flags = TerminalSamplingFlags(every: nil, mask: 0xF0, eq: 0xA0)
        let result = TerminalByteSampler.apply(flags: flags, to: [0x10, 0xA0, 0xB0, 0x05])
        XCTAssertEqual(result, [0xA0])
    }

    func testEveryNthByte() {
        let flags = TerminalSamplingFlags(every: 2, mask: nil, eq: nil)
        let result = TerminalByteSampler.apply(flags: flags, to: [1, 2, 3, 4, 5])
        XCTAssertEqual(result, [1, 3, 5])
    }

    func testMaskThenEvery() {
        let flags = TerminalSamplingFlags(every: 2, mask: 0xFF, eq: nil)
        let result = TerminalByteSampler.apply(flags: flags, to: [0x01, 0x02, 0x03, 0x04])
        XCTAssertEqual(result, [0x01, 0x03])
    }
}

final class TerminalCRCPresetTests: XCTestCase {
    func testPresetByRawValue() {
        XCTAssertEqual(CRCPreset.matching("crc16Modbus"), .crc16Modbus)
    }

    func testPresetBySuffix() {
        XCTAssertEqual(CRCPreset.matching("modbus"), .crc16Modbus)
    }

    func testPresetByLabel() {
        XCTAssertEqual(CRCPreset.matching("CRC-16/MODBUS"), .crc16Modbus)
    }
}

final class TerminalCommandParserTests: XCTestCase {
    private func makeProvider() -> (Range<Int>) -> [UInt8] {
        { range in
            (range.lowerBound..<range.upperBound).map { UInt8($0 & 0xFF) }
        }
    }

    func testBackwardCompatibleSum() {
        let result = TerminalCommandParser.execute("sum 0 100", fileSize: 200, bytesProvider: makeProvider())
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.contains("0x"))
    }

    func testMultiSegmentSum() {
        let result = TerminalCommandParser.execute("sum 0 1, 4 5", fileSize: 100, bytesProvider: makeProvider())
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.contains("0xA")) // 0+1+4+5 = 10
        XCTAssertTrue(text.contains("(10)"))
    }

    func testLenWithFilters() {
        let result = TerminalCommandParser.execute("len 0 7 --every 2", fileSize: 100, bytesProvider: makeProvider())
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.hasPrefix("4"))
    }

    func testCRCWithPreset() {
        let bytes: [UInt8] = [0x01, 0x02]
        let result = TerminalCommandParser.execute(
            "crc --preset modbus 0 1",
            fileSize: 10,
            bytesProvider: { _ in bytes }
        )
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.contains("CRC-16/MODBUS"))
    }

    func testHexDump() {
        let result = TerminalCommandParser.execute("hex 0 2", fileSize: 10, bytesProvider: { _ in [0xDE, 0xAD, 0xBE] })
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertEqual(text, "DEADBE")
    }

    func testFindPattern() {
        let provider = makeProvider()
        let result = TerminalCommandParser.execute("find 01 02", fileSize: 200, bytesProvider: provider)
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.contains("0x00000001"))
        XCTAssertTrue(text.contains("matches"))
    }

    func testFindASCII() {
        let bytes: [UInt8] = Array("ababcab".utf8)
        let result = TerminalCommandParser.execute(
            "find --ascii ab",
            fileSize: bytes.count,
            bytesProvider: { range in
                Array(bytes[range])
            }
        )
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.contains("0x"))
        XCTAssertTrue(text.contains("3 matches"))
    }

    func testFindNotFound() {
        let result = TerminalCommandParser.execute("find FF FF", fileSize: 10, bytesProvider: { _ in
            [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09]
        })
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertEqual(text, String(localized: "Not found"))
    }

    func testHelpTopics() {
        let overview = TerminalCommandParser.execute("help", fileSize: 0, bytesProvider: { _ in [] })
        let crc = TerminalCommandParser.execute("help crc", fileSize: 0, bytesProvider: { _ in [] })
        let ranges = TerminalCommandParser.execute("help ranges", fileSize: 0, bytesProvider: { _ in [] })
        let filters = TerminalCommandParser.execute("help filters", fileSize: 0, bytesProvider: { _ in [] })

        guard case .output(let overviewText) = overview,
              case .output(let crcText) = crc,
              case .output(let rangesText) = ranges,
              case .output(let filtersText) = filters else {
            return XCTFail("Expected help output")
        }

        XCTAssertTrue(overviewText.contains("help filters"))
        XCTAssertTrue(crcText.contains("--preset"))
        XCTAssertTrue(rangesText.contains("inclusive"))
        XCTAssertTrue(filtersText.contains("--mask"))
        XCTAssertTrue(filtersText.contains("--every"))
    }

    func testEqRequiresMask() {
        let result = TerminalCommandParser.execute("sum 0 10 --eq 0", fileSize: 100, bytesProvider: makeProvider())
        guard case .error = result else {
            return XCTFail("Expected error")
        }
    }

    func testCompareReportsAllDifferences() {
        let result = TerminalCommandParser.execute(
            "cmp 0 2, 3 5",
            fileSize: 10,
            bytesProvider: { range in
                (range.lowerBound..<range.upperBound).map { UInt8($0) }
            }
        )
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertTrue(text.contains("Diff at index 0"))
        XCTAssertTrue(text.contains("Diff at index 1"))
        XCTAssertTrue(text.contains("Diff at index 2"))
    }

    func testCompareEqualRanges() {
        let result = TerminalCommandParser.execute(
            "cmp 0 2, 0 2",
            fileSize: 10,
            bytesProvider: { range in
                (range.lowerBound..<range.upperBound).map { UInt8($0) }
            }
        )
        guard case .output(let text) = result else {
            return XCTFail("Expected output")
        }
        XCTAssertEqual(text, String(localized: "Equal"))
    }

    func testSumOutOfBoundsReportsFileSize() {
        let result = TerminalCommandParser.execute("sum 0 300", fileSize: 200, bytesProvider: makeProvider())
        guard case .error(let message) = result else {
            return XCTFail("Expected error")
        }
        XCTAssertTrue(message.contains("300"))
        XCTAssertTrue(message.contains("200"))
    }

    func testGotoEnd() {
        let result = TerminalCommandParser.execute("goto end", fileSize: 256, bytesProvider: makeProvider())
        guard case .navigate(let offset) = result else {
            return XCTFail("Expected navigate")
        }
        XCTAssertEqual(offset, 255)
    }

    func testGotoEndEmptyFile() {
        let result = TerminalCommandParser.execute("goto end", fileSize: 0, bytesProvider: { _ in [] })
        guard case .error(let message) = result else {
            return XCTFail("Expected error")
        }
        XCTAssertEqual(message, String(localized: "File is empty"))
    }
}
