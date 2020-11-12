/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
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
import Rubicon

@usableFromInline var UTF16LE_BOM: [UInt8] = [ 0xff, 0xfe ]
@usableFromInline var UTF16BE_BOM: [UInt8] = [ 0xfe, 0xff ]
@usableFromInline var UTF32LE_BOM: [UInt8] = [ 0xff, 0xfe, 0x00, 0x00 ]
@usableFromInline var UTF32BE_BOM: [UInt8] = [ 0x00, 0x00, 0xfe, 0xff ]

@usableFromInline var UTF16_HIGH_SURROGATE_START: [UInt8] = [ 0xd8, 0x00 ]
@usableFromInline var UTF16_HIGH_SURROGATE_END:   [UInt8] = [ 0xdc, 0x00 ]
@usableFromInline var UTF16_LOW_SURROGATE_START:  [UInt8] = [ 0xdc, 0x00 ]
@usableFromInline var UTF16_LOW_SURROGATE_END:    [UInt8] = [ 0xe0, 0x00 ]

@usableFromInline enum SwapAt: Int {
    case None  = 0
    case Word  = 16
    case DWord = 32
    case QWord = 64
}

open class SAXParser {

    public var delegate: SAXParserDelegate? = nil

    public private(set) var inputStream: InputStream
    public private(set) var filename:    String
    public private(set) var encoding:    String.Encoding = .utf8

    var charInputStream: CharInputStream! = nil

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - inputStream: the input stream.
    ///   - filename: the filename.
    ///
    public init(inputStream: InputStream, filename: String? = nil) {
        self.inputStream = inputStream
        self.filename = (filename ?? "urn:\(UUID().uuidString)")
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameter filename: the filename to read from.
    ///
    public convenience init?(filename: String) {
        guard let inputStream = InputStream(fileAtPath: filename) else { return nil }
        self.init(inputStream: inputStream, filename: filename)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameter url: the URL to read from.
    ///
    public convenience init?(url: URL) {
        guard let inputStream = InputStream(url: url) else { return nil }
        self.init(inputStream: inputStream, filename: url.description)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - data: the data object to read from.
    ///   - filename: the filename for the data.
    ///
    public convenience init(data: Data, filename: String? = nil) {
        self.init(inputStream: InputStream(data: data), filename: filename)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - data: the buffer to read the data from.
    ///   - filename: the filename for the data.
    ///
    public convenience init(data: UnsafeBufferPointer<UInt8>, filename: String? = nil) {
        self.init(inputStream: InputStream(data: Data(buffer: data)), filename: filename)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - data: the pointer to the data to read from.
    ///   - count: the number of bytes in the data.
    ///   - filename: the filename for the data.
    ///
    public convenience init(data: UnsafePointer<UInt8>, count: Int, filename: String? = nil) {
        self.init(inputStream: InputStream(data: Data(bytes: UnsafeRawPointer(data), count: count)), filename: filename)
    }

    /*===========================================================================================================================*/
    /// Parse the XML document.
    ///
    /// - Throws: if an error occurs during parsing.
    ///
    open func parse() throws {
        try createCharInputStream()
        //
        // Now we're going to look to see if we have a manifest on this bugger: <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        //
        var chars: [Character] = []
        var rslt = try charInputStream.read(chars: &chars, maxLength: 5)
        while rslt > 0 && chars.count < 5 { rslt = try charInputStream.read(chars: &chars, maxLength: 5 - chars.count, overWrite: false) }
        guard chars.count == 5 else { throw SAXError.UnexpectedEndOfFile }

        if String(chars) == "<?xml" {
            //
            // We have a manifest so we might be changing encoding.
            //

        }
    }

    /*===========================================================================================================================*/
    /// Determine the character encoding used and then create an instance of CharInputStream for us to use.
    ///
    /// - Throws: if an I/O error occurs or there is not at least 4 bytes of data to read from the input stream.
    ///
    func createCharInputStream() throws {
        let buffer: UnsafeMutablePointer<UInt8> = createMutablePointer(capacity: 4)
        defer { discardMutablePointer(buffer, 4) }
        if inputStream.streamStatus == .notOpen { inputStream.open() }

        let bi: ByteInputStream = ByteInputStream(inputStream: inputStream)
        try encodingCheck(bi, buffer: buffer)

        switch encoding { //@f:0
            case .utf16LittleEndian: charInputStream = Utf16CharInputStream(byteInputStream: bi, endian: CFByteOrderLittleEndian)
            case .utf16BigEndian   : charInputStream = Utf16CharInputStream(byteInputStream: bi, endian: CFByteOrderBigEndian)
            case .utf32LittleEndian: charInputStream = Utf32CharInputStream(byteInputStream: bi, endian: CFByteOrderLittleEndian)
            case .utf32BigEndian   : charInputStream = Utf32CharInputStream(byteInputStream: bi, endian: CFByteOrderBigEndian)
            default                : charInputStream = Utf8CharInputStream(byteInputStream: bi)
        } //@f:1
    }

    /*===========================================================================================================================*/
    /// <code>[Character](https://developer.apple.com/documentation/swift/character/)</code> Encoding Detection
    ///
    /// - Parameter buffer: the input buffer.
    /// - Throws: in the event of an I/O error.
    ///
    func encodingCheck(_ bInput: ByteInputStream, buffer: UnsafeMutablePointer<UInt8>) throws {
        // *****************************************************************************
        // *********************** CHARACTER ENCODING DETECTION ************************
        // *****************************************************************************
        // The first thing we do is read at least 4 bytes of data from the stream. That
        // should be enough to give us a good guess.
        //
        try readAtLeast(bInput, buffer: buffer, count: 4)
        bInput.unRead(src: buffer, length: 4)
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
    }

    /*===========================================================================================================================*/
    /// Check the bytes to see if they are a UTF-16 surrogate pair.
    ///
    /// - Parameter buffer: the buffer - should be at least 4 bytes.
    /// - Returns: `true` if these bytes represent a UTF-16 surrogate pair.
    ///
    @inlinable func surrogatePairCheck(buffer: UnsafeMutablePointer<UInt8>) -> Bool {
        memcmp(buffer, &UTF16_HIGH_SURROGATE_START, 2) >= 0 && memcmp(buffer, &UTF16_HIGH_SURROGATE_END, 2) < 0 &&
        memcmp(buffer + 2, &UTF16_LOW_SURROGATE_START, 2) >= 0 && memcmp(buffer + 2, &UTF16_LOW_SURROGATE_END, 2) < 0
    }

    /*===========================================================================================================================*/
    /// Make a copy of a buffer and, optionally, swap the endian-ness of the bytes.
    ///
    /// - Parameters:
    ///   - buffer: the buffer to make a copy of.
    ///   - count: the number of bytes to copy.
    ///   - s: swap
    /// - Returns: the copy.
    ///
    func copyBuffer<T>(buffer: UnsafePointer<T>, count: Int, swap s: SwapAt = .None) -> UnsafeMutablePointer<T> {
        let b = UnsafeMutablePointer<T>.allocate(capacity: count)
        b.initialize(from: buffer, count: count)
        switch s {
            case .Word:
                let cc = (count / 2)
                if cc > 0 { b.withMemoryRebound(to: UInt16.self, capacity: cc) { (p: UnsafeMutablePointer<UInt16>) -> Void in for i in (0 ..< cc) { p[i] = CFSwapInt16(p[i]) } } }
            case .DWord:
                let cc = (count / 4)
                if cc > 0 { b.withMemoryRebound(to: UInt32.self, capacity: cc) { (p: UnsafeMutablePointer<UInt32>) -> Void in for i in (0 ..< cc) { p[i] = CFSwapInt32(p[i]) } } }
            case .QWord:
                let cc = (count / 8)
                if cc > 0 { b.withMemoryRebound(to: UInt64.self, capacity: cc) { (p: UnsafeMutablePointer<UInt64>) -> Void in for i in (0 ..< cc) { p[i] = CFSwapInt64(p[i]) } } }
            default: break
        }
        return b
    }

    /*===========================================================================================================================*/
    /// Read `count` bytes from the input stream. Does not return until at least `count` bytes have been read. If the end-of-file
    /// is reached or an I/O error occurs before the required number of bytes have been read then an exception is thrown.
    ///
    /// - Parameters:
    ///   - buffer: the buffer to read the bytes into.
    ///   - count: the number of bytes to read.
    /// - Returns: the number of bytes actually read. (will always be the same as `count`)
    /// - Throws: an exception if the end-of-file is reached or an I/O error occurs before the required number of bytes has been
    ///           read.
    ///
    @discardableResult open func readAtLeast(_ bInput: ByteInputStream, buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> Int {
        var bytesRead: Int = 0
        repeat {
            let ioResult = try bInput.read(buffer: buffer + bytesRead, maxLength: count - bytesRead)
            guard ioResult > 0 else { throw SAXError.UnexpectedEndOfFile }
            bytesRead += ioResult
        }
        while bytesRead < count
        return bytesRead
    }

    /*===========================================================================================================================*/
    /// Convenience function for setting the delegate and calling parse in one call.
    ///
    /// - Parameter delegate: the `SAXParserDelegate`.
    /// - Throws: if an error occurs during parsing.
    ///
    @inlinable open func parse(delegate: SAXParserDelegate) throws {
        self.delegate = delegate
        try parse()
    }
}
