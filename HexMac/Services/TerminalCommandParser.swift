//
//  TerminalCommandParser.swift
//  HexMac
//

import Foundation

struct TerminalLine: Identifiable, Equatable {
    enum Kind: Equatable {
        case input
        case output
        case error
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

enum TerminalCommandResult {
    case output(String)
    case navigate(Int)
    case error(String)
}

enum TerminalCommandParser {
    private static let maxDumpBytes = BinarySelectionFormatter.maxDisplayBytes

    static func execute(
        _ input: String,
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error(String(localized: "Empty command"))
        }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let command = tokens.first?.lowercased() else {
            return .error(String(localized: "Invalid command"))
        }

        switch command {
        case "help":
            return runHelp(tokens: tokens)
        case "goto":
            return runGoto(tokens: tokens, fileSize: fileSize)
        case "sum":
            return runAggregate(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider, operation: .sum)
        case "xor":
            return runAggregate(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider, operation: .xor)
        case "avg":
            return runAggregate(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider, operation: .average)
        case "len":
            return runLength(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "crc":
            return runCRC(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "hex":
            return runHexDump(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "bin":
            return runBinDump(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "ascii":
            return runAsciiDump(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "min":
            return runMinMax(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider, operation: .min)
        case "max":
            return runMinMax(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider, operation: .max)
        case "count":
            return runCount(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "read":
            return runRead(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "find":
            return runFind(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "cmp":
            return runCompare(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        case "hash":
            return runHash(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider)
        default:
            return .error(String(localized: "Unknown command. Type help for available commands."))
        }
    }

    // MARK: - Parsing

    private struct ParsedCommand {
        let samplingFlags: TerminalSamplingFlags
        let crcOptions: TerminalCRCOptions?
        let positionalTokens: [String]
    }

    private static func parseCommandTokens(
        _ tokens: [String],
        parseCRCFlags: Bool
    ) -> Result<ParsedCommand, TerminalParseError> {
        let split = TerminalCommandTokenizer.split(commandTokens: tokens)

        if let validationError = TerminalCommandTokenizer.validate(
            flagTokens: split.flagTokens,
            allowCRCFlags: parseCRCFlags,
            allowSamplingFlags: true
        ) {
            return .failure(validationError)
        }

        var crcOptions: TerminalCRCOptions?

        if parseCRCFlags {
            switch TerminalCRCOptions.parse(flagTokens: split.flagTokens) {
            case .success(let options):
                crcOptions = options
            case .failure(let error):
                return .failure(error)
            }
        }

        switch TerminalSamplingFlags.parse(flagTokens: split.flagTokens) {
        case .success(let samplingFlags):
            if let validationError = samplingFlags.validate() {
                return .failure(validationError)
            }

            return .success(
                ParsedCommand(
                    samplingFlags: samplingFlags,
                    crcOptions: crcOptions,
                    positionalTokens: split.positionalTokens
                )
            )
        case .failure(let error):
            return .failure(error)
        }
    }

    private static func collectBytes(
        positionalTokens: [String],
        fileSize: Int,
        flags: TerminalSamplingFlags,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> Result<[UInt8], TerminalParseError> {
        switch TerminalRangeSpec.parse(positionalTokens: positionalTokens, fileSize: fileSize) {
        case .failure(let error):
            return .failure(error)
        case .success(let spec):
            let bytes = TerminalByteSampler.collect(from: spec, flags: flags, bytesProvider: bytesProvider)
            guard !bytes.isEmpty else {
                return .failure(TerminalParseError(message: String(localized: "Empty range")))
            }
            return .success(bytes)
        }
    }

    // MARK: - Commands

    private static func runHelp(tokens: [String]) -> TerminalCommandResult {
        if tokens.count == 1 {
            return .output(helpOverviewText)
        }

        switch tokens[1].lowercased() {
        case "crc":
            return .output(helpCRCText)
        case "ranges":
            return .output(helpRangesText)
        case "filters":
            return .output(helpFiltersText)
        default:
            return .output(helpOverviewText)
        }
    }

    private static func runGoto(tokens: [String], fileSize: Int) -> TerminalCommandResult {
        guard tokens.count == 2 else {
            return .error(String(localized: "Usage: goto <offset|end>"))
        }

        if tokens[1].lowercased() == "end" {
            guard fileSize > 0 else {
                return .error(String(localized: "File is empty"))
            }
            return .navigate(fileSize - 1)
        }

        guard let offset = TerminalOffsetParser.parse(tokens[1]) else {
            return .error(String(localized: "Usage: goto <offset|end>"))
        }
        if let boundsError = TerminalOffsetParser.validateInFile(offset: offset, text: tokens[1], fileSize: fileSize) {
            return .error(boundsError.message)
        }
        return .navigate(offset)
    }

    private static func runLength(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            switch collectBytes(
                positionalTokens: parsed.positionalTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(let bytes):
                return .output("\(bytes.count) \(String(localized: "bytes"))")
            }
        }
    }

    private enum AggregateOperation {
        case sum
        case xor
        case average
    }

    private static func runAggregate(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8],
        operation: AggregateOperation
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            switch collectBytes(
                positionalTokens: parsed.positionalTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(let bytes):
                switch operation {
                case .sum:
                    let total = bytes.reduce(0) { $0 + UInt64($1) }
                    return .output("0x\(String(total, radix: 16, uppercase: true)) (\(total))")
                case .xor:
                    let value = bytes.reduce(0) { $0 ^ UInt64($1) }
                    return .output("0x\(String(format: "%02X", value))")
                case .average:
                    let total = bytes.reduce(0) { $0 + UInt64($1) }
                    let average = Double(total) / Double(bytes.count)
                    return .output(String(format: "%.2f", average))
                }
            }
        }
    }

    private static func runCRC(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: true) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            let crcOptions = parsed.crcOptions ?? .default
            switch collectBytes(
                positionalTokens: parsed.positionalTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(var bytes):
                if crcOptions.reverseByteOrder {
                    bytes.reverse()
                }
                let value = CRCService.calculate(data: bytes, configuration: crcOptions.configuration)
                let formatted = CRCService.formattedResult(value, configuration: crcOptions.configuration)
                return .output("\(crcOptions.displayLabel): \(formatted)")
            }
        }
    }

    private static func runHexDump(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        dumpResult(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider) { bytes in
            bytes.map { HexFormatter.hexPair(for: $0) }.joined()
        }
    }

    private static func runBinDump(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        dumpResult(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider) { bytes in
            bytes.map { HexFormatter.binaryString(for: $0) }.joined()
        }
    }

    private static func runAsciiDump(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        dumpResult(tokens: tokens, fileSize: fileSize, bytesProvider: bytesProvider) { bytes in
            HexFormatter.asciiString(for: bytes)
        }
    }

    private static func dumpResult(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8],
        format: ([UInt8]) -> String
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            switch collectBytes(
                positionalTokens: parsed.positionalTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(let bytes):
                guard bytes.count <= maxDumpBytes else {
                    return .error(
                        String(
                            localized: "Output exceeds \(maxDumpBytes) bytes. Narrow the range or use filters."
                        )
                    )
                }
                return .output(format(bytes))
            }
        }
    }

    private enum MinMaxOperation {
        case min
        case max
    }

    private static func runMinMax(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8],
        operation: MinMaxOperation
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            switch collectBytes(
                positionalTokens: parsed.positionalTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(let bytes):
                let value: UInt8
                switch operation {
                case .min:
                    value = bytes.min() ?? 0
                case .max:
                    value = bytes.max() ?? 0
                }
                return .output("0x\(HexFormatter.hexPair(for: value)) (\(value))")
            }
        }
    }

    private static func runCount(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            guard let targetByte = parsed.positionalTokens.first.flatMap({ TerminalOffsetParser.parseByte($0) }) else {
                return .error(String(localized: "Usage: count <byte> <start> <end>[, ...]"))
            }

            let rangeTokens = Array(parsed.positionalTokens.dropFirst())
            switch collectBytes(
                positionalTokens: rangeTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(let bytes):
                let count = bytes.reduce(0) { $0 + ($1 == targetByte ? 1 : 0) }
                return .output("\(count)")
            }
        }
    }

    private enum ReadType: String {
        case u8, u16, u32, u64, i16, i32

        var byteCount: Int {
            switch self {
            case .u8: 1
            case .u16, .i16: 2
            case .u32, .i32: 4
            case .u64: 8
            }
        }

        var isSigned: Bool {
            switch self {
            case .i16, .i32: true
            default: false
            }
        }
    }

    private static func runRead(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        let split = TerminalCommandTokenizer.split(commandTokens: tokens)

        if let validationError = TerminalCommandTokenizer.validate(
            flagTokens: split.flagTokens,
            allowCRCFlags: false,
            allowSamplingFlags: false,
            allowReadFlags: true
        ) {
            return .error(validationError.message)
        }

        var littleEndian = true
        for flag in split.flagTokens.map({ $0.lowercased() }) {
            switch flag {
            case "--le":
                littleEndian = true
            case "--be":
                littleEndian = false
            default:
                break
            }
        }

        guard split.positionalTokens.count == 2,
              let type = ReadType(rawValue: split.positionalTokens[0].lowercased()),
              let offset = TerminalOffsetParser.parse(split.positionalTokens[1]) else {
            return .error(String(localized: "Usage: read <u8|u16|u32|u64|i16|i32> <offset> [--le|--be]"))
        }

        let endInclusive = offset + type.byteCount - 1
        if let boundsError = TerminalOffsetParser.validateInFile(
            offset: offset,
            text: split.positionalTokens[1],
            fileSize: fileSize
        ) {
            return .error(boundsError.message)
        }
        if endInclusive >= fileSize {
            let endText = String(endInclusive)
            return .error(
                TerminalOffsetParser.boundsError(offset: endInclusive, text: endText, fileSize: fileSize).message
            )
        }

        let bytes = bytesProvider(offset..<(offset + type.byteCount))
        guard bytes.count == type.byteCount else {
            return .error(String(localized: "Unable to read bytes at offset"))
        }

        let unsigned = unsignedValue(from: bytes, littleEndian: littleEndian)
        if type.isSigned {
            let signed = signExtend(unsigned, byteCount: type.byteCount)
            return .output("0x\(String(unsigned, radix: 16, uppercase: true)) (\(signed))")
        }
        return .output("0x\(String(unsigned, radix: 16, uppercase: true)) (\(unsigned))")
    }

    private static func runFind(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        let split = TerminalCommandTokenizer.split(commandTokens: tokens)
        let asciiMode = split.flagTokens.contains { $0.lowercased() == "--ascii" }
        let filteredFlags = split.flagTokens.filter { $0.lowercased() != "--ascii" }

        if let validationError = TerminalCommandTokenizer.validate(
            flagTokens: filteredFlags,
            allowCRCFlags: false,
            allowSamplingFlags: true
        ) {
            return .error(validationError.message)
        }

        switch TerminalSamplingFlags.parse(flagTokens: filteredFlags) {
        case .failure(let error):
            return .error(error.message)
        case .success(let flags):
            if let validationError = flags.validate() {
                return .error(validationError.message)
            }

            let patternResult: BytePatternParseResult
            if asciiMode {
                guard let asciiResult = BytePatternSearch.parseASCIITokens(split.positionalTokens) else {
                    return .error(String(localized: "Usage: find --ascii <text> [start end][, ...]"))
                }
                patternResult = asciiResult
            } else {
                switch BytePatternSearch.parseHexTokens(split.positionalTokens) {
                case .failure(let error):
                    return .error(error.localizedDescription)
                case .success(let result):
                    patternResult = result
                }
            }

            let segments: [Range<Int>]
            if patternResult.rangeTokens.isEmpty {
                segments = [0..<fileSize]
            } else {
                switch TerminalRangeSpec.parse(positionalTokens: patternResult.rangeTokens, fileSize: fileSize) {
                case .failure(let error):
                    return .error(error.message)
                case .success(let spec):
                    segments = spec.segments
                }
            }

            var allMatches: [Int] = []
            for segment in segments {
                allMatches.append(contentsOf: BytePatternSearch.findAll(
                    pattern: patternResult.pattern,
                    in: segment,
                    bytesProvider: bytesProvider
                ))
            }
            return .output(BytePatternSearch.formatMatches(allMatches))
        }
    }

    private static func runCompare(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            switch TerminalRangeSpec.parse(positionalTokens: parsed.positionalTokens, fileSize: fileSize) {
            case .failure(let error):
                return .error(error.message)
            case .success(let spec):
                guard spec.segments.count == 2 else {
                    return .error(String(localized: "cmp requires exactly two ranges separated by comma"))
                }

                let left = TerminalByteSampler.collect(
                    from: TerminalRangeSpec(segments: [spec.segments[0]]),
                    flags: parsed.samplingFlags,
                    bytesProvider: bytesProvider
                )
                let right = TerminalByteSampler.collect(
                    from: TerminalRangeSpec(segments: [spec.segments[1]]),
                    flags: parsed.samplingFlags,
                    bytesProvider: bytesProvider
                )

                guard !left.isEmpty, !right.isEmpty else {
                    return .error(String(localized: "Empty range"))
                }
                guard left.count == right.count else {
                    return .error(String(localized: "Ranges have different lengths: \(left.count) vs \(right.count)"))
                }

                let diffs = left.indices.compactMap { index -> String? in
                    guard left[index] != right[index] else { return nil }
                    return "Diff at index \(index): 0x\(HexFormatter.hexPair(for: left[index])) vs 0x\(HexFormatter.hexPair(for: right[index]))"
                }

                if diffs.isEmpty {
                    return .output(String(localized: "Equal"))
                }
                return .output(diffs.joined(separator: "\n"))
            }
        }
    }

    private static func runHash(
        tokens: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        switch parseCommandTokens(tokens, parseCRCFlags: false) {
        case .failure(let error):
            return .error(error.message)
        case .success(let parsed):
            guard let algorithmName = parsed.positionalTokens.first,
                  let algorithm = HashAlgorithm.matching(algorithmName) else {
                return .error(String(localized: "Usage: hash <algorithm> <start> <end>[, ...]"))
            }

            let rangeTokens = Array(parsed.positionalTokens.dropFirst())
            switch collectBytes(
                positionalTokens: rangeTokens,
                fileSize: fileSize,
                flags: parsed.samplingFlags,
                bytesProvider: bytesProvider
            ) {
            case .failure(let error):
                return .error(error.message)
            case .success(let bytes):
                return .output(HashAlgorithm.calculate(algorithm, data: bytes))
            }
        }
    }

    // MARK: - Helpers

    private static func unsignedValue(from bytes: [UInt8], littleEndian: Bool) -> UInt64 {
        var value: UInt64 = 0
        if littleEndian {
            for (index, byte) in bytes.enumerated() {
                value |= UInt64(byte) << (8 * index)
            }
        } else {
            for byte in bytes {
                value = (value << 8) | UInt64(byte)
            }
        }
        return value
    }

    private static func signExtend(_ value: UInt64, byteCount: Int) -> Int64 {
        let bitWidth = byteCount * 8
        let signBit = UInt64(1) << (bitWidth - 1)
        if value & signBit != 0 {
            let mask = (UInt64(1) << bitWidth) - 1
            return Int64(bitPattern: (~mask) | (value & mask))
        }
        return Int64(value)
    }

    // MARK: - Help

    private static let helpOverviewText = """
    help [crc|ranges|filters]
    goto <offset|end>

    Navigation:
      goto <offset>                 jump to byte offset in the file
      goto end                      jump to the last byte in the file

    Byte math (ranges + optional filters, see help filters):
      sum <ranges>                  sum of bytes → 0xHEX (decimal)
      xor <ranges>                  XOR of all bytes → 0xNN
      avg <ranges>                  average byte value
      len <ranges>                  count bytes after filters

    CRC (see help crc):
      crc <ranges> [--preset name] [--reverse] ...

    Dump (no separators, max 64 KB output):
      hex <ranges>                  raw hex: DEADBEEF
      bin <ranges>                  raw binary: 11010010...
      ascii <ranges>                printable text, others as '.'

    Analysis:
      min|max <ranges>              smallest / largest byte value
      count <byte> <ranges>         how many times <byte> appears
      read <type> <offset>          read u8|u16|u32|u64|i16|i32 at offset
                                    [--le] little-endian (default)
                                    [--be] big-endian
      find <pattern> [ranges]       search bytes; pattern: DEADBEEF or 0xDE 0xAD
      find --ascii <text> [ranges]  search ASCII text; lists all matches
      cmp <r1>, <r2>                compare two equal-length ranges
      hash <algorithm> <ranges>       md5, sha1, sha224, sha256, sha384, sha512,
                                      sha3-256, sha3-384, sha3-512

    Topics: help ranges | help filters | help crc
    """

    private static let helpRangesText = """
    Range syntax: <start> <end>[, <start> <end>...]

    Offsets: decimal (100) or hex (0x64). End is inclusive.
    Order in a pair does not matter. Segments are joined in order.

    Examples:
      sum 0 255                     bytes 0..255 (256 bytes)
      sum 0 255, 512 767            two segments, concatenated
      hex 0x0 0xFF, 512 0x3FF       mixed decimal and hex

    Optional filters (--mask, --eq, --every) apply after bytes are
    collected. See: help filters
    """

    private static let helpFiltersText = """
    Filters select which bytes from a range are processed.
    Applied in this order:

      1. Collect bytes from all range segments (in order)
      2. --mask / --eq  keep matching bytes
      3. --every N      keep every Nth byte from step 2

    --mask M
      Keep bytes where any masked bit is set: (byte & M) != 0
      M is a byte value: decimal or hex (0xF0).
      Example: --mask 0x80  keeps bytes with bit 7 set

    --eq V  (requires --mask)
      Keep bytes where (byte & M) == V
      Useful to match an exact bit pattern in the masked bits.
      Example: --mask 0xF0 --eq 0xA0  keeps 0xA?, not 0xB?

    --every N  (N >= 1)
      From the current byte list, keep indices 0, N, 2N, 3N, ...
      N=1 means no thinning. N=2 keeps 1st, 3rd, 5th... byte.
      Applied after --mask.

    Examples:
      sum 0 255 --every 4
        sum bytes 0, 4, 8, 12, ... from the range

      sum 0 0xFFFF --mask 0x80
        sum only bytes with high bit set

      crc --preset modbus 0 0xFF --every 2
        CRC over every 2nd byte of 0..255

      len 0 1000 --mask 0x0F --eq 0x05
        count bytes where low nibble equals 5

    Flags can appear before or after ranges:
      sum 0 255 --every 4
      sum --every 4 0 255
    """

    private static let helpCRCText = """
    crc [options] <ranges> [filters]

    Default: CRC-32/ISO-HDLC (Ethernet CRC).
    Filters (help filters) apply to input bytes before CRC.

    Preset / algorithm:
      --preset <name>     crc16Modbus, modbus, CRC-16/MODBUS, ...
      --crc8 | --crc16 | --crc32

    Custom parameters (override preset):
      --poly <hex>        polynomial
      --init <hex>        initial value
      --xorout <hex>      final XOR
      --refin             reflect input bytes
      --refout            reflect result

    Other:
      --reverse           reverse byte order before calculation

    Examples:
      crc 0 255
      crc --preset modbus 0 0x1F, 0x100 0x2FF
      crc --crc16 --poly 0x8005 --init 0xFFFF --refin --refout 0 100
      crc --preset modbus 0 255 --every 4
    """
}
