//
//  SelectionIntegerParser.swift
//  HexMac
//

import Foundation

struct IntegerInterpretation: Identifiable {
    let typeName: String
    let littleEndian: String
    let bigEndian: String

    var id: String { typeName }
}

enum SelectionIntegerParser {
    static func interpretations(for bytes: [UInt8]) -> [IntegerInterpretation] {
        guard !bytes.isEmpty else { return [] }

        return [
            IntegerInterpretation(
                typeName: "uint8_t",
                littleEndian: formatUnsigned(UInt8(paddedBytes(from: bytes, size: 1)[0]), hexWidth: 2),
                bigEndian: formatUnsigned(UInt8(paddedBytes(from: bytes, size: 1)[0]), hexWidth: 2)
            ),
            IntegerInterpretation(
                typeName: "int8_t",
                littleEndian: formatSigned(Int8(bitPattern: paddedBytes(from: bytes, size: 1)[0]), hexWidth: 2),
                bigEndian: formatSigned(Int8(bitPattern: paddedBytes(from: bytes, size: 1)[0]), hexWidth: 2)
            ),
            make16BitInterpretation(typeName: "uint16_t", bytes: bytes, signed: false),
            make16BitInterpretation(typeName: "int16_t", bytes: bytes, signed: true),
            make32BitInterpretation(typeName: "uint32_t", bytes: bytes, signed: false),
            make32BitInterpretation(typeName: "int32_t", bytes: bytes, signed: true),
            make64BitInterpretation(typeName: "uint64_t", bytes: bytes, signed: false),
            make64BitInterpretation(typeName: "int64_t", bytes: bytes, signed: true),
        ]
    }

    private static func paddedBytes(from bytes: [UInt8], size: Int) -> [UInt8] {
        let used = Array(bytes.prefix(size))
        if used.count >= size {
            return used
        }
        return used + Array(repeating: 0, count: size - used.count)
    }

    private static func make16BitInterpretation(
        typeName: String,
        bytes: [UInt8],
        signed: Bool
    ) -> IntegerInterpretation {
        let padded = paddedBytes(from: bytes, size: 2)
        let leBits = UInt16(padded[0]) | (UInt16(padded[1]) << 8)
        let beBits = (UInt16(padded[0]) << 8) | UInt16(padded[1])

        if signed {
            return IntegerInterpretation(
                typeName: typeName,
                littleEndian: formatSigned(Int16(bitPattern: leBits), hexWidth: 4),
                bigEndian: formatSigned(Int16(bitPattern: beBits), hexWidth: 4)
            )
        }

        return IntegerInterpretation(
            typeName: typeName,
            littleEndian: formatUnsigned(leBits, hexWidth: 4),
            bigEndian: formatUnsigned(beBits, hexWidth: 4)
        )
    }

    private static func make32BitInterpretation(
        typeName: String,
        bytes: [UInt8],
        signed: Bool
    ) -> IntegerInterpretation {
        let padded = paddedBytes(from: bytes, size: 4)
        let leBits = UInt32(padded[0])
            | (UInt32(padded[1]) << 8)
            | (UInt32(padded[2]) << 16)
            | (UInt32(padded[3]) << 24)
        let beBits = (UInt32(padded[0]) << 24)
            | (UInt32(padded[1]) << 16)
            | (UInt32(padded[2]) << 8)
            | UInt32(padded[3])

        if signed {
            return IntegerInterpretation(
                typeName: typeName,
                littleEndian: formatSigned(Int32(bitPattern: leBits), hexWidth: 8),
                bigEndian: formatSigned(Int32(bitPattern: beBits), hexWidth: 8)
            )
        }

        return IntegerInterpretation(
            typeName: typeName,
            littleEndian: formatUnsigned(leBits, hexWidth: 8),
            bigEndian: formatUnsigned(beBits, hexWidth: 8)
        )
    }

    private static func make64BitInterpretation(
        typeName: String,
        bytes: [UInt8],
        signed: Bool
    ) -> IntegerInterpretation {
        let padded = paddedBytes(from: bytes, size: 8)
        let leBits = padded.enumerated().reduce(UInt64(0)) { value, pair in
            value | (UInt64(pair.element) << (pair.offset * 8))
        }
        let beBits = padded.enumerated().reduce(UInt64(0)) { value, pair in
            value | (UInt64(pair.element) << ((7 - pair.offset) * 8))
        }

        if signed {
            return IntegerInterpretation(
                typeName: typeName,
                littleEndian: formatSigned(Int64(bitPattern: leBits), hexWidth: 16),
                bigEndian: formatSigned(Int64(bitPattern: beBits), hexWidth: 16)
            )
        }

        return IntegerInterpretation(
            typeName: typeName,
            littleEndian: formatUnsigned(leBits, hexWidth: 16),
            bigEndian: formatUnsigned(beBits, hexWidth: 16)
        )
    }

    private static func bitMask(forHexWidth hexWidth: Int) -> UInt64 {
        let bitCount = hexWidth * 4
        guard bitCount < 64 else { return UInt64.max }
        return (UInt64(1) << bitCount) &- 1
    }

    private static func formatUnsigned<T: FixedWidthInteger>(_ value: T, hexWidth: Int) -> String {
        let numeric = UInt64(truncatingIfNeeded: value)
        return "\(value) (0x\(String(format: "%0\(hexWidth)llX", numeric)))"
    }

    private static func formatSigned<T: SignedInteger & FixedWidthInteger>(_ value: T, hexWidth: Int) -> String {
        let bitPattern = UInt64(truncatingIfNeeded: value) & bitMask(forHexWidth: hexWidth)
        return "\(value) (0x\(String(format: "%0\(hexWidth)llX", bitPattern)))"
    }
}
