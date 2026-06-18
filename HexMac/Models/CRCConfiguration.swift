//
//  CRCConfiguration.swift
//  HexMac
//

import Foundation

enum CRCAlgorithm: String, CaseIterable, Identifiable {
    case crc8
    case crc16
    case crc32

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crc8:
            "CRC-8"
        case .crc16:
            "CRC-16"
        case .crc32:
            "CRC-32"
        }
    }

    var bitWidth: Int {
        switch self {
        case .crc8:
            8
        case .crc16:
            16
        case .crc32:
            32
        }
    }

    var resultHexDigits: Int {
        switch self {
        case .crc8:
            2
        case .crc16:
            4
        case .crc32:
            8
        }
    }
}

enum CRCPreset: String, CaseIterable, Identifiable {
    case crc32ISO
    case crc32HDLC
    case crc16CCITT
    case crc8

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crc32ISO:
            "CRC-32 (ISO)"
        case .crc32HDLC:
            "CRC-32 (HDLC)"
        case .crc16CCITT:
            "CRC-16 (CCITT)"
        case .crc8:
            "CRC-8"
        }
    }

    var configuration: CRCConfiguration {
        switch self {
        case .crc32ISO:
            CRCConfiguration(
                algorithm: .crc32,
                polynomial: 0x04C1_1DB7,
                initialValue: 0xFFFF_FFFF,
                refin: true,
                refout: true,
                xorOut: 0xFFFF_FFFF
            )
        case .crc32HDLC:
            CRCConfiguration(
                algorithm: .crc32,
                polynomial: 0x04C1_1DB7,
                initialValue: 0xFFFF_FFFF,
                refin: true,
                refout: true,
                xorOut: 0xFFFF_FFFF
            )
        case .crc16CCITT:
            CRCConfiguration(
                algorithm: .crc16,
                polynomial: 0x1021,
                initialValue: 0xFFFF,
                refin: false,
                refout: false,
                xorOut: 0x0000
            )
        case .crc8:
            CRCConfiguration(
                algorithm: .crc8,
                polynomial: 0x07,
                initialValue: 0x00,
                refin: false,
                refout: false,
                xorOut: 0x00
            )
        }
    }
}

struct CRCConfiguration: Equatable {
    var algorithm: CRCAlgorithm
    var polynomial: UInt64
    var initialValue: UInt64
    var refin: Bool
    var refout: Bool
    var xorOut: UInt64

    static var defaultConfiguration: CRCConfiguration {
        CRCPreset.crc32ISO.configuration
    }

    func applying(preset: CRCPreset) -> CRCConfiguration {
        preset.configuration
    }

    var polynomialHexString: String {
        formatHex(polynomial, digits: algorithm.bitWidth / 4)
    }

    var initialValueHexString: String {
        formatHex(initialValue, digits: algorithm.bitWidth / 4)
    }

    var xorOutHexString: String {
        formatHex(xorOut, digits: algorithm.bitWidth / 4)
    }

    mutating func setPolynomial(fromHex hex: String) {
        polynomial = parseHex(hex, maxBits: algorithm.bitWidth) ?? polynomial
    }

    mutating func setInitialValue(fromHex hex: String) {
        initialValue = parseHex(hex, maxBits: algorithm.bitWidth) ?? initialValue
    }

    mutating func setXorOut(fromHex hex: String) {
        xorOut = parseHex(hex, maxBits: algorithm.bitWidth) ?? xorOut
    }

    private func formatHex(_ value: UInt64, digits: Int) -> String {
        String(format: "%0\(digits)X", value)
    }

    private func parseHex(_ hex: String, maxBits: Int) -> UInt64? {
        let filtered = hex.uppercased().filter(\.isHexDigit)
        guard !filtered.isEmpty, let value = UInt64(filtered, radix: 16) else { return nil }
        let mask = maxBits >= 64 ? UInt64.max : (UInt64(1) << maxBits) - 1
        return value & mask
    }
}
