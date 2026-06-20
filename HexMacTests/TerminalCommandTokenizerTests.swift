//
//  TerminalCommandTokenizerTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class TerminalCommandTokenizerTests: XCTestCase {
    func testSplitFlagsAfterPositionalTokens() {
        let split = TerminalCommandTokenizer.split(commandTokens: ["sum", "0", "255", "--every", "4"])
        XCTAssertEqual(split.positionalTokens, ["0", "255"])
        XCTAssertEqual(split.flagTokens, ["--every", "4"])
    }

    func testSplitFlagsBeforePositionalTokens() {
        let split = TerminalCommandTokenizer.split(commandTokens: ["sum", "--every", "4", "0", "255"])
        XCTAssertEqual(split.positionalTokens, ["0", "255"])
        XCTAssertEqual(split.flagTokens, ["--every", "4"])
    }

    func testValidateRejectsSamplingFlagsOnRead() {
        let error = TerminalCommandTokenizer.validate(
            flagTokens: ["--every", "2"],
            allowCRCFlags: false,
            allowSamplingFlags: false,
            allowReadFlags: true
        )
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.message, String(localized: "Unknown flag: --every"))
    }

    func testValidateRejectsCRCFlagsWhenDisallowed() {
        let error = TerminalCommandTokenizer.validate(
            flagTokens: ["--preset", "modbus"],
            allowCRCFlags: false,
            allowSamplingFlags: true
        )
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.message, String(localized: "Unknown flag: --preset"))
    }

    func testValidateAcceptsCRCFlagsWhenAllowed() {
        let error = TerminalCommandTokenizer.validate(
            flagTokens: ["--preset", "modbus"],
            allowCRCFlags: true,
            allowSamplingFlags: true
        )
        XCTAssertNil(error)
    }

    func testMaskFlagConsumesValueToken() {
        let split = TerminalCommandTokenizer.split(commandTokens: ["sum", "--mask", "F0", "0", "255"])
        XCTAssertEqual(split.flagTokens, ["--mask", "F0"])
        XCTAssertEqual(split.positionalTokens, ["0", "255"])
    }
}
