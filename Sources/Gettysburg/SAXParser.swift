/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/14/21
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

fileprivate let UTF32LEBOM: [UInt8] = [ 0xFF, 0xFE, 0x00, 0x00 ]
fileprivate let UTF32BEBOM: [UInt8] = [ 0x00, 0x00, 0xFE, 0xFF ]
fileprivate let UTF16LEBOM: [UInt8] = [ 0xFF, 0xFE ]
fileprivate let UTF16BEBOM: [UInt8] = [ 0xFE, 0xFF ]

open class SAXParser<H: SAXHandler> {

    public enum DTDEntityType {
        case General
        case Parameter
    }

    public enum DTDExternalType {
        case System
        case Public
    }

    public enum DTDAttrType {
        case CDATA
        case ID
        case IDREF
        case IDREFS
        case ENTITY
        case ENTITIES
        case NMTOKEN
        case NMTOKENS
        case NOTATION
        case ENUMERATED
    }

    public enum DTDAttrDefaultType {
        case Required
        case Optional
        case Fixed
    }

    public internal(set) var handler: H? = nil
    public internal(set) var uri:     String

    public var allowedURIPrefixes: [String] = []
    public var willValidate:       Bool     = false

    let inputStream: MarkInputStream
    var charStream:  CharInputStream! = nil

    lazy var lock: RecursiveLock = RecursiveLock()

    public init(inputStream: InputStream, uri: String, handler: H? = nil) {
        self.handler = handler
        self.inputStream = MarkInputStream(inputStream: inputStream)
        self.uri = uri
    }

    @discardableResult open func parse() throws -> H {
        try lock.withLock { () -> H in
            guard let handler = handler else { throw SAXError.MissingHandler }

            if inputStream.streamStatus == .notOpen { inputStream.open() }
            inputStream.markSet()

            var encoding: String  = "UTF-8"
            var hasBom:   Bool    = false
            var bytes1:   [UInt8] = Array<UInt8>(repeating: 0, count: 4)
            var bytes2:   [UInt8] = []
            let rc:       Int     = inputStream.read(&bytes1, maxLength: 4)

            inputStream.markRelease()
            guard rc == 4 else { throw StreamError.UnexpectedEndOfInput() }
            bytes2.append(bytes1[0])
            bytes2.append(bytes1[1])

            if bytes1 == UTF32LEBOM { encoding = "UTF-32LE"; hasBom = true }
            else if bytes1 == UTF32BEBOM { encoding = "UTF-32BE"; hasBom = true }
            else if bytes2 == UTF16LEBOM { encoding = "UTF-16LE"; hasBom = true }
            else if bytes2 == UTF16BEBOM { encoding = "UTF-16BE"; hasBom = true }
            else if bytes1[0] == 0 && bytes1[1] == 0 && bytes1[3] != 0 { encoding = "UTF-32BE" }
            else if bytes1[0] != 0 && bytes1[2] == 0 && bytes1[3] == 0 { encoding = "UTF-32LE" }
            else if (bytes1[0] == 0 && bytes1[1] != 0) || (bytes1[2] == 0 && bytes1[3] != 0) { encoding = "UTF-16BE" }
            else if (bytes1[1] == 0 && bytes1[0] != 0) || (bytes1[3] == 0 && bytes1[2] != 0) { encoding = "UTF-16LE" }

            var decl: String? = nil
            let bc:   Int     = 100

            if encoding == "UTF-8" {
                bytes1 = Array<UInt8>(repeating: 0, count: bc + 1)
                inputStream.markSet()
                _ = inputStream.read(&bytes1, maxLength: bc)
                decl = String(cString: &bytes1)
            }
            else if encoding.hasPrefix("UTF-16") {
                let xbc = (bc * 2)
                bytes1 = Array<UInt8>(repeating: 0, count: xbc)
                inputStream.markSet()
                if hasBom {
                    let bomSize = 2
                    let rc: Int = inputStream.read(&bytes1, maxLength: bomSize)
                    guard rc == bomSize else { throw StreamError.UnexpectedEndOfInput() }
                }
                _ = inputStream.read(&bytes1, maxLength: xbc)
                decl = String(bytes: bytes1, encoding: encoding.hasSuffix("LE") ? .utf16LittleEndian : .utf16BigEndian)
            }
            else if encoding.hasPrefix("UTF-32") {
                let xbc = (bc * 4)
                bytes1 = Array<UInt8>(repeating: 0, count: xbc)
                inputStream.markSet()
                if hasBom {
                    let bomSize = 4
                    let rc: Int = inputStream.read(&bytes1, maxLength: bomSize)
                    guard rc == bomSize else { throw StreamError.UnexpectedEndOfInput() }
                }
                _ = inputStream.read(&bytes1, maxLength: xbc)
                decl = String(bytes: bytes1, encoding: encoding.hasSuffix("LE") ? .utf32LittleEndian : .utf32BigEndian)
            }

            print("XML Decl: \"\(decl ?? NULL)")

            //let rx = try RegEx(pattern: "\\<\\?xml\\s+version=\"([^\"]+)\"(?:\\s+encoding=\"([^\"]+)\")?(?:\\s+standalone=\"([^\"]+)\")?\\s*\\?\\>")
            return handler
        }
    }

    @discardableResult public final func set(handler: H) throws -> SAXParser<H> {
        guard self.handler == nil else { throw SAXError.HandlerAlreadySet }
        self.handler = handler
        return self
    }

    @discardableResult open func set(willValidate flag: Bool) -> SAXParser<H> {
        self.willValidate = flag
        return self
    }

    @discardableResult open func set(allowedUriPrefixes uris: [String], append: Bool = false) -> SAXParser<H> {
        if append { allowedURIPrefixes.append(contentsOf: uris) }
        else { allowedURIPrefixes = uris }
        return self
    }
}

extension SAXParser.DTDExternalType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .System: return "System"
            case .Public: return "Public"
        }
    }
}

extension SAXParser.DTDEntityType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .General:   return "General"
            case .Parameter: return "Parameter"
        }
    }
}

extension SAXParser.DTDAttrType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .CDATA:      return "CDATA"
            case .ID:         return "ID"
            case .IDREF:      return "IDREF"
            case .IDREFS:     return "IDREFS"
            case .ENTITY:     return "ENTITY"
            case .ENTITIES:   return "ENTITIES"
            case .NMTOKEN:    return "NMTOKEN"
            case .NMTOKENS:   return "NMTOKENS"
            case .NOTATION:   return "NOTATION"
            case .ENUMERATED: return "ENUMERATED"
        }
    }
}

extension SAXParser.DTDAttrDefaultType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Required: return "Required"
            case .Optional: return "Optional"
            case .Fixed:    return "Fixed"
        }
    }
}
