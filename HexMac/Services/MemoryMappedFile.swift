//
//  MemoryMappedFile.swift
//  HexMac
//

import Foundation
import Darwin

enum MemoryMappedFileError: Error, LocalizedError {
    case openFailed
    case mmapFailed
    case outOfBounds
    case writeProtected
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .openFailed:
            String(localized: "Failed to open file")
        case .mmapFailed:
            String(localized: "Failed to map file into memory")
        case .outOfBounds:
            String(localized: "Read out of bounds")
        case .writeProtected:
            String(localized: "File is read-only")
        case .syncFailed:
            String(localized: "Failed to sync file to disk")
        }
    }
}

final class MemoryMappedFile {
    private var fd: Int32
    private var pointer: UnsafeMutableRawPointer?
    private var hasSecurityScope: Bool

    let url: URL
    let size: Int
    let readOnly: Bool

    static func open(url: URL, readOnly: Bool = true) throws -> MemoryMappedFile {
        try MemoryMappedFile(url: url, readOnly: readOnly)
    }

    private init(url: URL, readOnly: Bool) throws {
        self.url = url
        self.readOnly = readOnly
        self.fd = -1
        self.hasSecurityScope = false
        self.pointer = nil

        hasSecurityScope = url.startAccessingSecurityScopedResource()

        let flags = readOnly ? O_RDONLY : O_RDWR
        fd = Darwin.open(url.path, flags)
        guard fd >= 0 else {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
                hasSecurityScope = false
            }
            throw MemoryMappedFileError.openFailed
        }

        var fileStat = stat()
        guard fstat(fd, &fileStat) == 0 else {
            Darwin.close(fd)
            fd = -1
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
                hasSecurityScope = false
            }
            throw MemoryMappedFileError.openFailed
        }

        let fileSize = Int(fileStat.st_size)

        if fileSize > 0 {
            let protection = readOnly ? PROT_READ : (PROT_READ | PROT_WRITE)
            let mapFlags = readOnly ? MAP_PRIVATE : MAP_SHARED
            let mapped = mmap(nil, fileSize, protection, mapFlags, fd, 0)
            guard mapped != MAP_FAILED else {
                Darwin.close(fd)
                fd = -1
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                    hasSecurityScope = false
                }
                throw MemoryMappedFileError.mmapFailed
            }
            pointer = mapped
        }

        self.size = fileSize
    }

    deinit {
        close()
    }

    func byte(at offset: Int) throws -> UInt8 {
        guard offset >= 0, offset < size, let pointer else {
            throw MemoryMappedFileError.outOfBounds
        }
        return pointer.load(fromByteOffset: offset, as: UInt8.self)
    }

    func bytes(in range: Range<Int>) throws -> [UInt8] {
        guard range.lowerBound >= 0, range.upperBound <= size, let pointer else {
            throw MemoryMappedFileError.outOfBounds
        }
        return range.map { pointer.load(fromByteOffset: $0, as: UInt8.self) }
    }

    func replaceByte(at offset: Int, with value: UInt8) throws {
        guard !readOnly else { throw MemoryMappedFileError.writeProtected }
        guard offset >= 0, offset < size, let pointer else {
            throw MemoryMappedFileError.outOfBounds
        }
        pointer.storeBytes(of: value, toByteOffset: offset, as: UInt8.self)
    }

    func replaceBytes(in range: Range<Int>, with value: UInt8) throws -> [UInt8] {
        guard !readOnly else { throw MemoryMappedFileError.writeProtected }
        guard range.lowerBound >= 0, range.upperBound <= size, let pointer else {
            throw MemoryMappedFileError.outOfBounds
        }

        var oldValues: [UInt8] = []
        oldValues.reserveCapacity(range.count)
        for offset in range {
            let oldValue = pointer.load(fromByteOffset: offset, as: UInt8.self)
            oldValues.append(oldValue)
            pointer.storeBytes(of: value, toByteOffset: offset, as: UInt8.self)
        }
        return oldValues
    }

    func sync() throws {
        guard let pointer, size > 0 else { return }
        let result = msync(pointer, size, MS_SYNC)
        guard result == 0 else { throw MemoryMappedFileError.syncFailed }
    }

    func close() {
        if let pointer, size > 0 {
            munmap(pointer, size)
            self.pointer = nil
        }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        if hasSecurityScope {
            url.stopAccessingSecurityScopedResource()
            hasSecurityScope = false
        }
    }
}
