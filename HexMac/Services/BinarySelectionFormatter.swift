//
//  BinarySelectionFormatter.swift
//  HexMac
//

import Foundation

struct BinaryIntegerInterpretation: Identifiable {
    let endianness: String
    let decimalValue: String
    let formattedBinaryText: String
    let plainBinaryText: String

    var id: String { endianness }
}

enum BinarySelectionFormatter {
    static let bytesPerLine = 8
    static let byteSeparator = " │ "
    static let maxDisplayBytes = 65_536
    static let maxCopyBytes = 4_194_304

    static func displayedByteCount(for totalByteCount: Int) -> Int {
        min(totalByteCount, maxDisplayBytes)
    }

    static func lineCount(for byteCount: Int) -> Int {
        guard byteCount > 0 else { return 0 }
        return (byteCount + bytesPerLine - 1) / bytesPerLine
    }

    static func relativeLineRange(for lineIndex: Int, totalByteCount: Int) -> Range<Int> {
        let start = lineIndex * bytesPerLine
        let end = min(start + bytesPerLine, totalByteCount)
        return start..<end
    }

    static func formattedLine(bytes: [UInt8], lineStartOffset: Int) -> String {
        let binary = bytes
            .map { HexFormatter.binaryString(for: $0) }
            .joined(separator: byteSeparator)
        return "0x\(HexFormatter.offsetString(for: lineStartOffset)): \(binary)"
    }

    static func integerInterpretations(for bytes: [UInt8]) -> [BinaryIntegerInterpretation] {
        guard !bytes.isEmpty, bytes.count <= 8 else { return [] }

        let littleEndianValue = unsignedValue(from: bytes, littleEndian: true)
        let bigEndianValue = unsignedValue(from: bytes, littleEndian: false)
        let littleEndianBinary = binaryGroups(for: littleEndianValue, byteCount: bytes.count, littleEndian: true)
        let bigEndianBinary = binaryGroups(for: bigEndianValue, byteCount: bytes.count, littleEndian: false)

        if littleEndianValue == bigEndianValue {
            return [
                BinaryIntegerInterpretation(
                    endianness: String(localized: "Value"),
                    decimalValue: "\(littleEndianValue)",
                    formattedBinaryText: littleEndianBinary,
                    plainBinaryText: plainBinaryGroups(
                        for: littleEndianValue,
                        byteCount: bytes.count,
                        littleEndian: true
                    )
                ),
            ]
        }

        return [
            BinaryIntegerInterpretation(
                endianness: String(localized: "Little-endian"),
                decimalValue: "\(littleEndianValue)",
                formattedBinaryText: littleEndianBinary,
                plainBinaryText: plainBinaryGroups(
                    for: littleEndianValue,
                    byteCount: bytes.count,
                    littleEndian: true
                )
            ),
            BinaryIntegerInterpretation(
                endianness: String(localized: "Big-endian"),
                decimalValue: "\(bigEndianValue)",
                formattedBinaryText: bigEndianBinary,
                plainBinaryText: plainBinaryGroups(
                    for: bigEndianValue,
                    byteCount: bytes.count,
                    littleEndian: false
                )
            ),
        ]
    }

    static func plainBinaryText(
        selectionStart: Int,
        byteCount: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> String {
        guard byteCount > 0 else { return "" }
        let bytes = bytesProvider(selectionStart..<(selectionStart + byteCount))
        return HexFormatter.binaryString(for: bytes, bitWidth: byteCount * 8)
    }

    static func wrappedPlainBinaryText(_ text: String, charactersPerLine: Int) -> String {
        guard charactersPerLine > 0, !text.isEmpty else { return text }

        var lines: [String] = []
        lines.reserveCapacity((text.count + charactersPerLine - 1) / charactersPerLine)

        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: charactersPerLine, limitedBy: text.endIndex) ?? text.endIndex
            lines.append(String(text[index..<end]))
            index = end
        }

        return lines.joined(separator: "\n")
    }

    static func fullText(
        selectionStart: Int,
        byteCount: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> String {
        guard byteCount > 0 else { return "" }

        var lines: [String] = []
        lines.reserveCapacity(lineCount(for: byteCount))

        for lineIndex in 0..<lineCount(for: byteCount) {
            let relativeRange = relativeLineRange(for: lineIndex, totalByteCount: byteCount)
            let absoluteRange = (selectionStart + relativeRange.lowerBound)..<(selectionStart + relativeRange.upperBound)
            let bytes = bytesProvider(absoluteRange)
            lines.append(formattedLine(bytes: bytes, lineStartOffset: absoluteRange.lowerBound))
        }

        return lines.joined(separator: "\n")
    }

    private static func unsignedValue(from bytes: [UInt8], littleEndian: Bool) -> UInt64 {
        bytes.enumerated().reduce(UInt64(0)) { value, pair in
            let shift = littleEndian
                ? pair.offset * 8
                : (bytes.count - 1 - pair.offset) * 8
            return value | (UInt64(pair.element) << shift)
        }
    }

    private static func binaryGroups(for value: UInt64, byteCount: Int, littleEndian: Bool) -> String {
        (0..<byteCount).map { index in
            let byteIndex = littleEndian ? index : (byteCount - 1 - index)
            let byte = UInt8((value >> (byteIndex * 8)) & 0xFF)
            return HexFormatter.binaryString(for: byte)
        }
        .joined(separator: byteSeparator)
    }

    private static func plainBinaryGroups(for value: UInt64, byteCount: Int, littleEndian: Bool) -> String {
        (0..<byteCount).map { index in
            let byteIndex = littleEndian ? index : (byteCount - 1 - index)
            let byte = UInt8((value >> (byteIndex * 8)) & 0xFF)
            return HexFormatter.binaryString(for: byte)
        }
        .joined()
    }
}
