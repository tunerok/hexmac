//
//  HashService.swift
//  HexMac
//

import CommonCrypto
import CryptoKit
import Foundation

enum HashAlgorithm: String, CaseIterable, Identifiable {
    case md5
    case sha1
    case sha224
    case sha256
    case sha384
    case sha512

    var id: String { rawValue }

    var label: String {
        switch self {
        case .md5:
            "MD5"
        case .sha1:
            "SHA-1"
        case .sha224:
            "SHA-224"
        case .sha256:
            "SHA-256"
        case .sha384:
            "SHA-384"
        case .sha512:
            "SHA-512"
        }
    }

    static func matching(_ name: String) -> HashAlgorithm? {
        let normalized = normalizeName(name)
        return allCases.first {
            normalizeName($0.rawValue) == normalized || normalizeName($0.label) == normalized
        }
    }

    static func calculate(_ algorithm: HashAlgorithm, data: [UInt8]) -> String {
        switch algorithm {
        case .md5:
            hexString(Insecure.MD5.hash(data: data))
        case .sha1:
            hexString(Insecure.SHA1.hash(data: data))
        case .sha224:
            sha224(data: data)
        case .sha256:
            hexString(SHA256.hash(data: data))
        case .sha384:
            hexString(SHA384.hash(data: data))
        case .sha512:
            hexString(SHA512.hash(data: data))
        }
    }

    static func calculate(
        _ algorithm: HashAlgorithm,
        in range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize
    ) -> String {
        switch algorithm {
        case .md5:
            return streamingHex(Insecure.MD5.self, range: range, bytesProvider: bytesProvider, chunkSize: chunkSize)
        case .sha1:
            return streamingHex(Insecure.SHA1.self, range: range, bytesProvider: bytesProvider, chunkSize: chunkSize)
        case .sha256:
            return streamingHex(SHA256.self, range: range, bytesProvider: bytesProvider, chunkSize: chunkSize)
        case .sha384:
            return streamingHex(SHA384.self, range: range, bytesProvider: bytesProvider, chunkSize: chunkSize)
        case .sha512:
            return streamingHex(SHA512.self, range: range, bytesProvider: bytesProvider, chunkSize: chunkSize)
        case .sha224:
            return streamingSHA224(range: range, bytesProvider: bytesProvider, chunkSize: chunkSize)
        }
    }

    private static func streamingHex<H: HashFunction>(
        _ type: H.Type,
        range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8],
        chunkSize: Int
    ) -> String {
        var hasher = H()
        ChunkedByteReader.forEachChunk(in: range, chunkSize: chunkSize, bytesProvider: bytesProvider) { chunk, _ in
            hasher.update(data: chunk)
        }
        return hexString(hasher.finalize())
    }

    private static func streamingSHA224(
        range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8],
        chunkSize: Int
    ) -> String {
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        ChunkedByteReader.forEachChunk(in: range, chunkSize: chunkSize, bytesProvider: bytesProvider) { chunk, _ in
            chunk.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                _ = CC_SHA224_Update(&context, baseAddress, CC_LONG(buffer.count))
            }
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
        _ = CC_SHA224_Final(&digest, &context)
        return hexString(digest)
    }

    private static func normalizeName(_ name: String) -> String {
        name.lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(Character.init)
            .reduce(into: "") { $0.append($1) }
    }

    private static func hexString(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha224(data: [UInt8]) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = CC_SHA224(baseAddress, CC_LONG(buffer.count), &digest)
        }
        return hexString(digest)
    }
}
