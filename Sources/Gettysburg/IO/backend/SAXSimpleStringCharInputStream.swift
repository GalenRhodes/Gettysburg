/*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXSimpleStringCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 4/14/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

private let uint32Stride = MemoryLayout<UInt32>.stride

class SAXSimpleStringCharInputStream: SAXSimpleCharInputStream {
    //@f:0
    public              let url:               URL
    public              let baseURL:           URL
    public              let filename:          String
    public              let streamError:       Error?        = nil
    public              let encodingName:      String        = UTF_32
    public              var tabWidth:          Int8          = 4
    public              var isEOF:             Bool          { (isOpen && !hasChars)                     }
    public              var hasCharsAvailable: Bool          { (isOpen && hasChars)                      }
    public              var streamStatus:      Stream.Status { ((isOpen && !hasChars) ? .atEnd : status) }
    public private(set) var position:          TextPosition  = (0, 0)
    //@f:1

    private var status: Stream.Status = .notOpen
    private let string: String
    private let endIdx: String.Index
    private var curIdx: String.Index

    private var hasChars: Bool { (curIdx < endIdx) }
    private var isOpen:   Bool { (status == .open) }

    init(_ string: String, _ url: URL) throws {
        (self.url, baseURL, filename) = try GetBaseURLAndFilename(url: url)
        self.string = string
        endIdx = string.endIndex
        curIdx = string.startIndex
    }

    convenience init(_ data: Data, _ url: URL, skipXMLDeclaration: Bool = true) throws {
        let enc = try getCharacterEncoding(MarkInputStream(data: data))
        let str = try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> String in
            let icv = IConv(toEncoding: UTF_8, fromEncoding: enc, ignoreErrors: true, enableTransliterate: true)
            guard let inBuff: EasyByteBuffer = EasyByteBuffer(buffer: buffer) else { return "" }
            let outBuff               = EasyByteBuffer(length: ((inBuff.length * uint32Stride) + uint32Stride))
            let result: IConv.Results = icv.convert(input: inBuff, output: outBuff)

            if result == IConv.Results.UnknownEncoding { throw SAXError.UnsupportedCharacterEncoding(0, 0, description: "Unknown Character Encoding: \"\(enc)\"") }
            if result == IConv.Results.OtherError { throw StreamError.UnknownError() }

            return outBuff.withBytes { (bytes: UnsafeMutablePointer<UInt8>, length: Int, count: inout Int) -> String in
                if result == IConv.Results.IncompleteSequence { for b: UInt8 in UnicodeReplacementChar.utf8 { bytes[count++] = b } }
                bytes[count++] = 0
                return String(cString: bytes)
            }
        }

        try self.init(str, url)

        if skipXMLDeclaration, let rx = RegularExpression(pattern: "^<\\?xml\\s+(.+?)\\?>", options: [ .caseInsensitive, .dotMatchesLineSeparators ]) {
            string.forEach(match: rx.firstMatch(in: string)) { textPositionUpdate($0, pos: &position, tabWidth: tabWidth) }
        }
    }

    func read() throws -> CharPos? {
        guard hasCharsAvailable else { return nil }
        let r = (string[curIdx], position)
        string.formIndex(after: &curIdx)
        textPositionUpdate(r.0, pos: &position, tabWidth: tabWidth)
        return r
    }

    func append(to chars: inout [CharPos], maxLength: Int) throws -> Int {
        guard hasCharsAvailable else { return 0 }
        let cc   = chars.count
        let idxS = (string.index(curIdx, offsetBy: ((maxLength < 0) ? Int.max : maxLength), limitedBy: endIdx) ?? endIdx)

        for ch in string[idxS ..< endIdx] {
            chars <+ (ch, position)
            textPositionUpdate(ch, pos: &position, tabWidth: tabWidth)
        }
        curIdx = idxS
        return (chars.count - cc)
    }

    func open() {
        if status == .notOpen {
            position = (1, 1)
            status = .open
        }
    }

    func close() {
        if status == .open {
            status = .closed
            position = (0, 0)
        }
    }
}
