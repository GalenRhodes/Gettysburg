/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXTools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/27/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
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
#if os(Windows)
    import WinSDK
#endif

/*===============================================================================================================================================================================*/
/// The BOM (byte order mark) indicating UTF-32 Little Endian.
///
let UTF32LEBOM: [UInt8]       = [ 0xFF, 0xFE, 0x00, 0x00 ]
/*===============================================================================================================================================================================*/
/// The BOM (byte order mark) indicating UTF-32 Big Endian.
///
let UTF32BEBOM: [UInt8]       = [ 0x00, 0x00, 0xFE, 0xFF ]
/*===============================================================================================================================================================================*/
/// The BOM (byte order mark) indicating UTF-16 Little Endian.
///
let UTF16LEBOM: [UInt8]       = [ 0xFF, 0xFE ]
/*===============================================================================================================================================================================*/
/// The BOM (byte order mark) indicating UTF-16 Big Endian.
///
let UTF16BEBOM: [UInt8]       = [ 0xFE, 0xFF ]
/*===============================================================================================================================================================================*/
/// A mapping of the number of bytes per ASCII character for each encoding.
///
let UNITSIZE:   [String: Int] = [ "UTF-8": 1, "UTF-16LE": 2, "UTF-16BE": 2, "UTF-32LE": 4, "UTF-32BE": 4 ]

/*===============================================================================================================================================================================*/
/// Compares the suffix array to the end of the source array to see if they are the same.
///
/// - Parameters:
///   - sfx: the suffix array.
///   - src: the source array.
/// - Returns: `true` if the last sfx.count elements of the source array are the same as the suffix array. If the length of the source array (src.count) is less than the length of
///            the suffix array (sfx.count) then the return value will be `false`.
///
@inlinable func cmpSuffix<S>(suffix sfx: S, source src: S) -> Bool where S: RandomAccessCollection, S.Element: Equatable {
    guard sfx.count > 0 && sfx.count <= src.count else { return false }

    var sfxIndex = sfx.endIndex
    var srcIndex = src.endIndex
    let sfxStart = sfx.startIndex

    while sfxIndex > sfxStart {
        sfxIndex = sfx.index(before: sfxIndex)
        srcIndex = src.index(before: srcIndex)
        if sfx[sfxIndex] != src[srcIndex] { return false }
    }

    return true
}

/*===============================================================================================================================================================================*/
/// Compares the prefix array to the beginning of the source array to see if they are the same.
///
/// - Parameters:
///   - pfx: the prefix array.
///   - src: the source array.
/// - Returns: `true` if the last pfx.count elements of the source array are the same as the prefix array. If the length of the source array (src.count) is less than the length of
///            the prefix array (pfx.count) then the return value will be `false`.
///
@inlinable func cmpPrefix<S>(prefix pfx: S, source src: S) -> Bool where S: RandomAccessCollection, S.Element: Equatable {
    guard pfx.count > 0 && pfx.count <= src.count else { return false }

    var pfxIndex = pfx.startIndex
    var srcIndex = src.startIndex
    let pfxEnd   = pfx.endIndex

    while pfxIndex < pfxEnd {
        if pfx[pfxIndex] != src[srcIndex] { return false }
        pfxIndex = pfx.index(after: pfxIndex)
        srcIndex = src.index(after: srcIndex)
    }

    return true
}

extension InputStream {
    /*===========================================================================================================================================================================*/
    /// Read a single byte from the input stream.
    ///
    /// - Returns: the next byte or `nil` if the end-of-file has been reached.
    /// - Throws: if an I/O error occurred.
    ///
    @inlinable func read() throws -> UInt8? {
        var bt: UInt8 = 0
        let rc: Int   = read(&bt, maxLength: 1)
        if rc < 0 { throw streamError ?? StreamError.UnknownError() }
        return ((rc == 0) ? nil : bt)
    }
}

@inlinable func ret<T>(_ v: T, _ body: () throws -> Void) rethrows -> T {
    try body()
    return v
}

@inlinable func qName(prefix: String?, localName: String) -> String { ((prefix == nil) ? localName : "\(prefix!):\(localName)") }

/// Creates and returns an absolute file URL for the fileAtPath relative to the current working directory path.
///
/// - Parameter fileAtPath: the file path.
/// - Returns: the absolute file URL.
///
@inlinable func urlFor(fileAtPath: String) -> URL { URL(fileURLWithPath: fileAtPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) }
