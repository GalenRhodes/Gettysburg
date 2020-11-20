/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Tools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/7/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public var UTF16LE_BOM: [UInt8] = [ 0xff, 0xfe ]
public var UTF16BE_BOM: [UInt8] = [ 0xfe, 0xff ]
public var UTF32LE_BOM: [UInt8] = [ 0xff, 0xfe, 0x00, 0x00 ]
public var UTF32BE_BOM: [UInt8] = [ 0x00, 0x00, 0xfe, 0xff ]

public var UTF16_HIGH_SURROGATE_START: [UInt8] = [ 0xd8, 0x00 ]
public var UTF16_HIGH_SURROGATE_END:   [UInt8] = [ 0xdc, 0x00 ]
public var UTF16_LOW_SURROGATE_START:  [UInt8] = [ 0xdc, 0x00 ]
public var UTF16_LOW_SURROGATE_END:    [UInt8] = [ 0xe0, 0x00 ]

@usableFromInline let TabWidth: Int = 8

@inlinable func calcTab(col: Int) -> Int { (((((col - 1) + TabWidth) / TabWidth) * TabWidth) + 1) }

public enum SwapAs: Int {
    /*===========================================================================================================================*/
    /// No swaping.
    ///
    case None  = 0
    /*===========================================================================================================================*/
    /// Swap as 16-bit words.
    ///
    case Word  = 16
    /*===========================================================================================================================*/
    /// Swap as 32-bit words.
    ///
    case DWord = 32
    /*===========================================================================================================================*/
    /// Swap as 64-bit words.
    ///
    case QWord = 64
}

/*===============================================================================================================================*/
/// <code>[Character](https://developer.apple.com/documentation/swift/character/)</code> Encoding Detection
/// 
/// - Parameter buffer: the input buffer.
/// - Throws: in the event of an I/O error.
///
public func encodingCheck(_ bInput: ByteInputStream, buffer: UnsafeMutablePointer<UInt8>) throws -> String.Encoding {
    let encoding: String.Encoding
    // *****************************************************************************
    // *********************** CHARACTER ENCODING DETECTION ************************
    // *****************************************************************************
    //
    // The we'll start by looking the "Byte Order Mark", or BOM, for UTF-16 and UTF-
    // 32. We start with UTF-32 first because UTF-16 Little Endian and UTF-32 Little
    // Endian start out with the same two bytes.  If it's not UTF-32 then we look
    // for UTF-16.
    //
    if memcmp(buffer, &UTF32LE_BOM, 4) == 0 {
        encoding = .utf32LittleEndian
    }
    else if memcmp(buffer, &UTF32BE_BOM, 4) == 0 {
        encoding = .utf32BigEndian
    }
    else if memcmp(buffer, &UTF16LE_BOM, 2) == 0 {
        encoding = .utf16LittleEndian
    }
    else if memcmp(buffer, &UTF16BE_BOM, 2) == 0 {
        encoding = .utf16BigEndian
    }
    //
    // If we didn't find any BOM then we make a guess based on where we find
    // any zero byte values. We will start with UTF-16.
    //
    else if (buffer[0] != 0 && buffer[1] == 0 && buffer[2] != 0 && buffer[3] == 0) {
        encoding = .utf16BigEndian
    }
    else if (buffer[0] == 0 && buffer[1] != 0 && buffer[2] == 0 && buffer[3] != 0) {
        encoding = .utf16LittleEndian
    }
    //
    // Also look to see if maybe the first two 16-bit words are UTF-16 high
    // and low surrogates which would indicate that we're starting off with
    // an extended character.
    //
    else if surrogatePairCheck(buffer: buffer) {
        encoding = .utf16BigEndian
    }
    else {
        //
        // Do the same again but with the bytes swapped around for little endian.
        //
        let b2: UnsafeMutablePointer<UInt8> = copyBuffer(buffer: buffer, count: 4, swap: .Word)
        defer { discardMutablePointer(b2, 4) }
        if surrogatePairCheck(buffer: b2) { encoding = .utf16LittleEndian }
        //
        // We're pretty confident that it's not UTF-16 so look to see if it's UTF-32.
        //
        else if (buffer[0] != 0 && buffer[1] == 0 && buffer[2] == 0 && buffer[3] == 0) { encoding = .utf32BigEndian }
        else if (buffer[0] == 0 && buffer[1] == 0 && buffer[2] == 0 && buffer[3] != 0) { encoding = .utf32LittleEndian }
        //
        // At this point if we didn't get a hit on anything we're going to assume
        // that this is UTF-8 data until something tells us different.
        //
        else { encoding = .utf8 }
    }
    return encoding
}

/*===============================================================================================================================*/
/// Check the bytes to see if they are a UTF-16 surrogate pair.
/// 
/// - Parameter buffer: the buffer - should be at least 4 bytes.
/// - Returns: `true` if these bytes represent a UTF-16 surrogate pair.
///
func surrogatePairCheck(buffer: UnsafeMutablePointer<UInt8>) -> Bool {
    memcmp(buffer, &UTF16_HIGH_SURROGATE_START, 2) >= 0 && memcmp(buffer, &UTF16_HIGH_SURROGATE_END, 2) < 0 &&
    memcmp(buffer + 2, &UTF16_LOW_SURROGATE_START, 2) >= 0 && memcmp(buffer + 2, &UTF16_LOW_SURROGATE_END, 2) < 0
}

/*===============================================================================================================================*/
/// Make a copy of a buffer and, optionally, swap the endian-ness of the bytes.
/// 
/// - Parameters:
///   - buffer: the buffer to make a copy of.
///   - count: the number of bytes to copy.
///   - s: swap
/// - Returns: the copy.
///
func copyBuffer<T>(buffer: UnsafePointer<T>, count: Int, swap s: SwapAs = .None) -> UnsafeMutablePointer<T> {
    let b = UnsafeMutablePointer<T>.allocate(capacity: count)
    b.initialize(from: buffer, count: count)
    SwapEndian(bytes: UnsafeMutablePointer(b), count: count, swap: s)
    return b
}

/*===============================================================================================================================*/
/// Utility function to swap the bytes (endian-ness) for various word sizes.
/// 
/// - Parameters:
///   - bytes: the buffer of bytes.
///   - count: the number of bytes in the buffer.
///   - swap: what word size to swap them as.
///
func SwapEndian(bytes: UnsafeMutableRawPointer, count: Int, swap: SwapAs) {
    switch swap {
        case .Word:
            let cc:   Int         = (count / MemoryLayout<UInt16>.size)
            let wrds: WordPointer = bytes.bindMemory(to: UInt16.self, capacity: cc)
            for i in (0 ..< cc) { wrds[i] = CFSwapInt16(wrds[i]) }
        case .DWord:
            let cc:   Int          = (count / MemoryLayout<UInt32>.size)
            let wrds: DWordPointer = bytes.bindMemory(to: UInt32.self, capacity: cc)
            for i in (0 ..< cc) { wrds[i] = CFSwapInt32(wrds[i]) }
        case .QWord:
            let cc:   Int          = (count / MemoryLayout<UInt64>.size)
            let wrds: QWordPointer = bytes.bindMemory(to: UInt64.self, capacity: cc)
            for i in (0 ..< cc) { wrds[i] = CFSwapInt64(wrds[i]) }
        default: break
    }
}

extension String {
    func isOneOf(_ str: String...) -> Bool {
        for s in str {
            if self == s { return true }
        }
        return false
    }
}

let AscIICharsXlate: [String] = [
    "<NUL>", "<SOH>", "<STX>", "<ETX>", "<EOT>", "<ENQ>", "<ACK>", "<BEL>", "<BS>", "<TAB>", "<LF>", "<VT>", "<FF>", "<CR>", "<SO>", "<SI>",
    "<DLE>", "<DC1>", "<DC2>", "<DC3>", "<DC4>", "<NAK>", "<SYN>", "<ETB>", "<CAN>", "<EM>", "<SUB>", "<ESC>", "<FS>", "<GS>", "<RS>", "<US>"
]

extension Character {
    @usableFromInline var printable: String {
        let sc: UnicodeScalarView = unicodeScalars
        if sc.count == 1 {
            let sv: UInt32 = sc[sc.startIndex].value
            if sv <= 32 { return AscIICharsXlate[Int(sv)] }
            if sv == 127 { return "<DEL>" }
        }
        return "\(self)"
    }
}
