//
//  FileReference.swift
//  ediHex
//

import Darwin
import Foundation

private func isRegularFile(_ mode: mode_t) -> Bool {
    (mode & S_IFMT) == S_IFREG
}

final class FileReference: @unchecked Sendable {
    private var fd: Int32
    private var hasSecurityScope: Bool

    let url: URL
    private(set) var length: UInt64
    private(set) var inode: UInt64
    private(set) var device: UInt64
    let readOnly: Bool

    static func open(url: URL, readOnly: Bool = true) throws -> FileReference {
        try FileReference(url: url, readOnly: readOnly)
    }

    private init(url: URL, readOnly: Bool) throws {
        self.url = url
        self.readOnly = readOnly
        self.fd = -1
        self.hasSecurityScope = url.startAccessingSecurityScopedResource()
        self.length = 0
        self.inode = 0
        self.device = 0

        let flags = readOnly ? O_RDONLY : (O_RDWR | O_CREAT)
        fd = Darwin.open(url.path, flags, 0o644)
        guard fd >= 0 else {
            cleanupOnFailure()
            throw ByteArrayError.openFailed
        }

        var fileStat = stat()
        guard fstat(fd, &fileStat) == 0 else {
            cleanupOnFailure()
            throw ByteArrayError.openFailed
        }

        guard isRegularFile(fileStat.st_mode) else {
            cleanupOnFailure()
            throw ByteArrayError.openFailed
        }

        inode = UInt64(fileStat.st_ino)
        device = UInt64(fileStat.st_dev)
        length = UInt64(fileStat.st_size)

        _ = fcntl(fd, F_NOCACHE, 1)
    }

    deinit {
        close()
    }

    nonisolated func isSameFile(as other: FileReference) -> Bool {
        inode == other.inode && device == other.device
    }

    nonisolated func read(into buffer: UnsafeMutableRawPointer, length count: Int, from offset: UInt64) throws {
        guard count >= 0, offset <= self.length else { throw ByteArrayError.outOfBounds }
        guard UInt64(count) <= self.length - offset else { throw ByteArrayError.outOfBounds }
        guard count > 0 else { return }

        let result = pread(fd, buffer, count, off_t(offset))
        guard result == count else { throw ByteArrayError.readFailed }
    }

    func write(from buffer: UnsafeRawPointer, length count: Int, to offset: UInt64) throws {
        guard !readOnly else { throw ByteArrayError.writeProtected }
        guard count >= 0 else { throw ByteArrayError.outOfBounds }
        guard count > 0 else { return }

        let result = pwrite(fd, buffer, count, off_t(offset))
        guard result == count else { throw ByteArrayError.writeFailed }
    }

    func setLength(_ newLength: UInt64) throws {
        guard !readOnly else { throw ByteArrayError.writeProtected }
        guard newLength <= UInt64(Int.max) else { throw ByteArrayError.fileTooLarge }

        guard ftruncate(fd, off_t(newLength)) == 0 else {
            throw ByteArrayError.resizeFailed
        }
        length = newLength
    }

    func close() {
        closeFD()
        stopSecurityScopeIfNeeded()
    }

    private func cleanupOnFailure() {
        closeFD()
        stopSecurityScopeIfNeeded()
    }

    private func closeFD() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    private func stopSecurityScopeIfNeeded() {
        if hasSecurityScope {
            url.stopAccessingSecurityScopedResource()
            hasSecurityScope = false
        }
    }
}
