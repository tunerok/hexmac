//
//  HashService.swift
//  HexMac
//

import CryptoKit
import Foundation

enum HashAlgorithm: String, CaseIterable, Identifiable {
    case md5
    case sha1
    case sha256

    var id: String { rawValue }

    var label: String {
        switch self {
        case .md5:
            "MD5"
        case .sha1:
            "SHA-1"
        case .sha256:
            "SHA-256"
        }
    }

    static func calculate(_ algorithm: HashAlgorithm, data: [UInt8]) -> String {
        switch algorithm {
        case .md5:
            Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha1:
            Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha256:
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }
}
