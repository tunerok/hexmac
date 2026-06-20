//
//  TerminalOffsetParserTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class TerminalOffsetParserTests: XCTestCase {
    func testParseDecimal() {
        XCTAssertEqual(TerminalOffsetParser.parse("100"), 100)
    }

    func testParseHex() {
        XCTAssertEqual(TerminalOffsetParser.parse("0xFF"), 255)
    }

    func testParseEndKeyword() {
        XCTAssertEqual(TerminalOffsetParser.parse("end", fileSize: 256), 255)
    }

    func testParseInvalidHexReturnsNil() {
        XCTAssertNil(TerminalOffsetParser.parse("0xGG"))
    }

    func testParseByteInRange() {
        XCTAssertEqual(TerminalOffsetParser.parseByte("0x12"), 0x12)
        XCTAssertEqual(TerminalOffsetParser.parseByte("255"), 255)
    }

    func testParseByteOutOfRangeReturnsNil() {
        XCTAssertNil(TerminalOffsetParser.parseByte("256"))
        XCTAssertNil(TerminalOffsetParser.parseByte("-1"))
    }

    func testParseUInt64Hex() {
        XCTAssertEqual(TerminalOffsetParser.parseUInt64("0x10"), 16)
    }

    func testValidateInFileAcceptsValidOffset() {
        XCTAssertNil(TerminalOffsetParser.validateInFile(offset: 0, text: "0", fileSize: 10))
        XCTAssertNil(TerminalOffsetParser.validateInFile(offset: 9, text: "9", fileSize: 10))
    }

    func testValidateInFileRejectsOutOfBounds() {
        let error = TerminalOffsetParser.validateInFile(offset: 10, text: "10", fileSize: 10)
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.message.contains("10") == true)
        XCTAssertTrue(error?.message.contains("10") == true)
    }

    func testValidateRangeInFileRejectsNegativeStart() {
        let error = TerminalOffsetParser.validateRangeInFile(
            start: -1,
            endInclusive: 5,
            startText: "-1",
            endText: "5",
            fileSize: 10
        )
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.message.contains("-1") == true)
    }

    func testValidateRangeInFileRejectsEndPastEOF() {
        let error = TerminalOffsetParser.validateRangeInFile(
            start: 0,
            endInclusive: 10,
            startText: "0",
            endText: "10",
            fileSize: 10
        )
        XCTAssertNotNil(error)
        XCTAssertTrue(error?.message.contains("10") == true)
    }

    func testBoundsErrorIncludesFileSize() {
        let error = TerminalOffsetParser.boundsError(offset: 20, text: "20", fileSize: 10)
        XCTAssertTrue(error.message.contains("20"))
        XCTAssertTrue(error.message.contains("10"))
    }
}
