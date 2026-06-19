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
    // CRC-8
    case crc8Autosar
    case crc8Bluetooth
    case crc8Cdma2000
    case crc8Darc
    case crc8DvbS2
    case crc8GsmA
    case crc8GsmB
    case crc8Hitag
    case crc8I4321
    case crc8ICode
    case crc8Lte
    case crc8MaximDow
    case crc8MifareMad
    case crc8Nrsc5
    case crc8Opensafety
    case crc8Rohc
    case crc8SaeJ1850
    case crc8Smbus
    case crc8Tech3250
    case crc8Wcdma

    // CRC-16
    case crc16Arc
    case crc16Cdma2000
    case crc16Cms
    case crc16Dds110
    case crc16DectR
    case crc16DectX
    case crc16Dnp
    case crc16En13757
    case crc16Genibus
    case crc16Gsm
    case crc16Ibm3740
    case crc16IbmSdlc
    case crc16IsoIec144433A
    case crc16Kermit
    case crc16Lj1200
    case crc16M17
    case crc16MaximDow
    case crc16Mcrf4xx
    case crc16Modbus
    case crc16Nrsc5
    case crc16OpensafetyA
    case crc16OpensafetyB
    case crc16Profibus
    case crc16Riello
    case crc16SpiFujitsu
    case crc16T10Dif
    case crc16Teledisk
    case crc16Tms37157
    case crc16Umts
    case crc16Usb
    case crc16Xmodem

    // CRC-32
    case crc32Aixm
    case crc32Autosar
    case crc32Base91D
    case crc32Bzip2
    case crc32CdRomEdc
    case crc32Cksum
    case crc32Iscsi
    case crc32IsoHdlc
    case crc32Jamcrc
    case crc32Mef
    case crc32Mpeg2
    case crc32Xfer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .crc8Autosar: "CRC-8/AUTOSAR"
        case .crc8Bluetooth: "CRC-8/BLUETOOTH"
        case .crc8Cdma2000: "CRC-8/CDMA2000"
        case .crc8Darc: "CRC-8/DARC"
        case .crc8DvbS2: "CRC-8/DVB-S2"
        case .crc8GsmA: "CRC-8/GSM-A"
        case .crc8GsmB: "CRC-8/GSM-B"
        case .crc8Hitag: "CRC-8/HITAG"
        case .crc8I4321: "CRC-8/I-432-1"
        case .crc8ICode: "CRC-8/I-CODE"
        case .crc8Lte: "CRC-8/LTE"
        case .crc8MaximDow: "CRC-8/MAXIM-DOW"
        case .crc8MifareMad: "CRC-8/MIFARE-MAD"
        case .crc8Nrsc5: "CRC-8/NRSC-5"
        case .crc8Opensafety: "CRC-8/OPENSAFETY"
        case .crc8Rohc: "CRC-8/ROHC"
        case .crc8SaeJ1850: "CRC-8/SAE-J1850"
        case .crc8Smbus: "CRC-8/SMBUS"
        case .crc8Tech3250: "CRC-8/TECH-3250"
        case .crc8Wcdma: "CRC-8/WCDMA"
        case .crc16Arc: "CRC-16/ARC"
        case .crc16Cdma2000: "CRC-16/CDMA2000"
        case .crc16Cms: "CRC-16/CMS"
        case .crc16Dds110: "CRC-16/DDS-110"
        case .crc16DectR: "CRC-16/DECT-R"
        case .crc16DectX: "CRC-16/DECT-X"
        case .crc16Dnp: "CRC-16/DNP"
        case .crc16En13757: "CRC-16/EN-13757"
        case .crc16Genibus: "CRC-16/GENIBUS"
        case .crc16Gsm: "CRC-16/GSM"
        case .crc16Ibm3740: "CRC-16/IBM-3740"
        case .crc16IbmSdlc: "CRC-16/IBM-SDLC"
        case .crc16IsoIec144433A: "CRC-16/ISO-IEC-14443-3-A"
        case .crc16Kermit: "CRC-16/KERMIT"
        case .crc16Lj1200: "CRC-16/LJ1200"
        case .crc16M17: "CRC-16/M17"
        case .crc16MaximDow: "CRC-16/MAXIM-DOW"
        case .crc16Mcrf4xx: "CRC-16/MCRF4XX"
        case .crc16Modbus: "CRC-16/MODBUS"
        case .crc16Nrsc5: "CRC-16/NRSC-5"
        case .crc16OpensafetyA: "CRC-16/OPENSAFETY-A"
        case .crc16OpensafetyB: "CRC-16/OPENSAFETY-B"
        case .crc16Profibus: "CRC-16/PROFIBUS"
        case .crc16Riello: "CRC-16/RIELLO"
        case .crc16SpiFujitsu: "CRC-16/SPI-FUJITSU"
        case .crc16T10Dif: "CRC-16/T10-DIF"
        case .crc16Teledisk: "CRC-16/TELEDISK"
        case .crc16Tms37157: "CRC-16/TMS37157"
        case .crc16Umts: "CRC-16/UMTS"
        case .crc16Usb: "CRC-16/USB"
        case .crc16Xmodem: "CRC-16/XMODEM"
        case .crc32Aixm: "CRC-32/AIXM"
        case .crc32Autosar: "CRC-32/AUTOSAR"
        case .crc32Base91D: "CRC-32/BASE91-D"
        case .crc32Bzip2: "CRC-32/BZIP2"
        case .crc32CdRomEdc: "CRC-32/CD-ROM-EDC"
        case .crc32Cksum: "CRC-32/CKSUM"
        case .crc32Iscsi: "CRC-32/ISCSI"
        case .crc32IsoHdlc: "CRC-32/ISO-HDLC"
        case .crc32Jamcrc: "CRC-32/JAMCRC"
        case .crc32Mef: "CRC-32/MEF"
        case .crc32Mpeg2: "CRC-32/MPEG-2"
        case .crc32Xfer: "CRC-32/XFER"
        }
    }

    var configuration: CRCConfiguration {
        switch self {
        case .crc8Autosar:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x2F, initialValue: 0xFF, refin: false, refout: false, xorOut: 0xFF)
        case .crc8Bluetooth:
            CRCConfiguration(algorithm: .crc8, polynomial: 0xA7, initialValue: 0x00, refin: true, refout: true, xorOut: 0x00)
        case .crc8Cdma2000:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x9B, initialValue: 0xFF, refin: false, refout: false, xorOut: 0x00)
        case .crc8Darc:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x39, initialValue: 0x00, refin: true, refout: true, xorOut: 0x00)
        case .crc8DvbS2:
            CRCConfiguration(algorithm: .crc8, polynomial: 0xD5, initialValue: 0x00, refin: false, refout: false, xorOut: 0x00)
        case .crc8GsmA:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x1D, initialValue: 0x00, refin: false, refout: false, xorOut: 0x00)
        case .crc8GsmB:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x49, initialValue: 0x00, refin: false, refout: false, xorOut: 0xFF)
        case .crc8Hitag:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x1D, initialValue: 0xFF, refin: false, refout: false, xorOut: 0x00)
        case .crc8I4321:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x07, initialValue: 0x00, refin: false, refout: false, xorOut: 0x55)
        case .crc8ICode:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x1D, initialValue: 0xFD, refin: false, refout: false, xorOut: 0x00)
        case .crc8Lte:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x9B, initialValue: 0x00, refin: false, refout: false, xorOut: 0x00)
        case .crc8MaximDow:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x31, initialValue: 0x00, refin: true, refout: true, xorOut: 0x00)
        case .crc8MifareMad:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x1D, initialValue: 0xC7, refin: false, refout: false, xorOut: 0x00)
        case .crc8Nrsc5:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x31, initialValue: 0xFF, refin: false, refout: false, xorOut: 0x00)
        case .crc8Opensafety:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x2F, initialValue: 0x00, refin: false, refout: false, xorOut: 0x00)
        case .crc8Rohc:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x07, initialValue: 0xFF, refin: true, refout: true, xorOut: 0x00)
        case .crc8SaeJ1850:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x1D, initialValue: 0xFF, refin: false, refout: false, xorOut: 0xFF)
        case .crc8Smbus:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x07, initialValue: 0x00, refin: false, refout: false, xorOut: 0x00)
        case .crc8Tech3250:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x1D, initialValue: 0xFF, refin: true, refout: true, xorOut: 0x00)
        case .crc8Wcdma:
            CRCConfiguration(algorithm: .crc8, polynomial: 0x9B, initialValue: 0x00, refin: true, refout: true, xorOut: 0x00)
        case .crc16Arc:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0x0000, refin: true, refout: true, xorOut: 0x0000)
        case .crc16Cdma2000:
            CRCConfiguration(algorithm: .crc16, polynomial: 0xC867, initialValue: 0xFFFF, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Cms:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0xFFFF, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Dds110:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0x800D, refin: false, refout: false, xorOut: 0x0000)
        case .crc16DectR:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x0589, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0001)
        case .crc16DectX:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x0589, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Dnp:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x3D65, initialValue: 0x0000, refin: true, refout: true, xorOut: 0xFFFF)
        case .crc16En13757:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x3D65, initialValue: 0x0000, refin: false, refout: false, xorOut: 0xFFFF)
        case .crc16Genibus:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0xFFFF, refin: false, refout: false, xorOut: 0xFFFF)
        case .crc16Gsm:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0x0000, refin: false, refout: false, xorOut: 0xFFFF)
        case .crc16Ibm3740:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0xFFFF, refin: false, refout: false, xorOut: 0x0000)
        case .crc16IbmSdlc:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0xFFFF, refin: true, refout: true, xorOut: 0xFFFF)
        case .crc16IsoIec144433A:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0xC6C6, refin: true, refout: true, xorOut: 0x0000)
        case .crc16Kermit:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0x0000, refin: true, refout: true, xorOut: 0x0000)
        case .crc16Lj1200:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x6F63, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16M17:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x5935, initialValue: 0xFFFF, refin: false, refout: false, xorOut: 0x0000)
        case .crc16MaximDow:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0x0000, refin: true, refout: true, xorOut: 0xFFFF)
        case .crc16Mcrf4xx:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0xFFFF, refin: true, refout: true, xorOut: 0x0000)
        case .crc16Modbus:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0xFFFF, refin: true, refout: true, xorOut: 0x0000)
        case .crc16Nrsc5:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x080B, initialValue: 0xFFFF, refin: true, refout: true, xorOut: 0x0000)
        case .crc16OpensafetyA:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x5935, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16OpensafetyB:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x755B, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Profibus:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1DCF, initialValue: 0xFFFF, refin: false, refout: false, xorOut: 0xFFFF)
        case .crc16Riello:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0xB2AA, refin: true, refout: true, xorOut: 0x0000)
        case .crc16SpiFujitsu:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0x1D0F, refin: false, refout: false, xorOut: 0x0000)
        case .crc16T10Dif:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8BB7, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Teledisk:
            CRCConfiguration(algorithm: .crc16, polynomial: 0xA097, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Tms37157:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0x89EC, refin: true, refout: true, xorOut: 0x0000)
        case .crc16Umts:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc16Usb:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x8005, initialValue: 0xFFFF, refin: true, refout: true, xorOut: 0xFFFF)
        case .crc16Xmodem:
            CRCConfiguration(algorithm: .crc16, polynomial: 0x1021, initialValue: 0x0000, refin: false, refout: false, xorOut: 0x0000)
        case .crc32Aixm:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x8141_41AB, initialValue: 0x0000_0000, refin: false, refout: false, xorOut: 0x0000_0000)
        case .crc32Autosar:
            CRCConfiguration(algorithm: .crc32, polynomial: 0xF4AC_FB13, initialValue: 0xFFFF_FFFF, refin: true, refout: true, xorOut: 0xFFFF_FFFF)
        case .crc32Base91D:
            CRCConfiguration(algorithm: .crc32, polynomial: 0xA833_982B, initialValue: 0xFFFF_FFFF, refin: true, refout: true, xorOut: 0xFFFF_FFFF)
        case .crc32Bzip2:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x04C1_1DB7, initialValue: 0xFFFF_FFFF, refin: false, refout: false, xorOut: 0xFFFF_FFFF)
        case .crc32CdRomEdc:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x8001_801B, initialValue: 0x0000_0000, refin: true, refout: true, xorOut: 0x0000_0000)
        case .crc32Cksum:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x04C1_1DB7, initialValue: 0x0000_0000, refin: false, refout: false, xorOut: 0xFFFF_FFFF)
        case .crc32Iscsi:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x1EDC_6F41, initialValue: 0xFFFF_FFFF, refin: true, refout: true, xorOut: 0xFFFF_FFFF)
        case .crc32IsoHdlc:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x04C1_1DB7, initialValue: 0xFFFF_FFFF, refin: true, refout: true, xorOut: 0xFFFF_FFFF)
        case .crc32Jamcrc:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x04C1_1DB7, initialValue: 0xFFFF_FFFF, refin: true, refout: true, xorOut: 0x0000_0000)
        case .crc32Mef:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x741B_8CD7, initialValue: 0xFFFF_FFFF, refin: true, refout: true, xorOut: 0x0000_0000)
        case .crc32Mpeg2:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x04C1_1DB7, initialValue: 0xFFFF_FFFF, refin: false, refout: false, xorOut: 0x0000_0000)
        case .crc32Xfer:
            CRCConfiguration(algorithm: .crc32, polynomial: 0x0000_00AF, initialValue: 0x0000_0000, refin: false, refout: false, xorOut: 0x0000_0000)
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
        CRCPreset.crc32IsoHdlc.configuration
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
