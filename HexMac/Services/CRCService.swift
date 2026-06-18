//
//  CRCService.swift
//  HexMac
//

import Foundation

enum CRCService {
    static func calculate(data: [UInt8], configuration: CRCConfiguration) -> UInt64 {
        let width = configuration.algorithm.bitWidth
        let mask = bitMask(for: width)
        let polynomial = configuration.polynomial & mask
        var crc = configuration.initialValue & mask
        let topBit = UInt64(1) << (width - 1)

        for byte in data {
            var inputByte = UInt64(byte)
            if configuration.refin {
                inputByte = reflect(value: inputByte, bitCount: 8)
            }

            crc ^= inputByte << (width - 8)

            for _ in 0..<8 {
                if crc & topBit != 0 {
                    crc = ((crc << 1) & mask) ^ polynomial
                } else {
                    crc = (crc << 1) & mask
                }
            }
        }

        if configuration.refout {
            crc = reflect(value: crc, bitCount: width)
        }

        return (crc ^ configuration.xorOut) & mask
    }

    static func formattedResult(_ value: UInt64, configuration: CRCConfiguration) -> String {
        String(format: "0x%0\(configuration.algorithm.resultHexDigits)X", value)
    }

    private static func bitMask(for width: Int) -> UInt64 {
        guard width < 64 else { return UInt64.max }
        return (UInt64(1) << width) - 1
    }

    private static func reflect(value: UInt64, bitCount: Int) -> UInt64 {
        var result: UInt64 = 0
        var input = value
        for _ in 0..<bitCount {
            result = (result << 1) | (input & 1)
            input >>= 1
        }
        return result
    }
}
