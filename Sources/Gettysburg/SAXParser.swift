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

fileprivate let UTF32LEBOM: [UInt8]       = [ 0xFF, 0xFE, 0x00, 0x00 ]
fileprivate let UTF32BEBOM: [UInt8]       = [ 0x00, 0x00, 0xFE, 0xFF ]
fileprivate let UTF16LEBOM: [UInt8]       = [ 0xFF, 0xFE ]
fileprivate let UTF16BEBOM: [UInt8]       = [ 0xFE, 0xFF ]
fileprivate let UNITSIZE:   [String: Int] = [ "UTF-8": 1, "UTF-16LE": 2, "UTF-16BE": 2, "UTF-32LE": 4, "UTF-32BE": 4 ]

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
            var encoding: String = "UTF-8"

            guard let handler = handler else { throw SAXError.MissingHandler }
            if inputStream.streamStatus == .notOpen { inputStream.open() }

            //------------------------------------------------
            // Try to determine the encoding of the XML file.
            //------------------------------------------------
            do {
                inputStream.markSet()
                defer { inputStream.markRelease() }

                let buffSize:     Int         = 500
                let buffer:       BytePointer = BytePointer.allocate(capacity: buffSize)
                let hostEncoding: String      = "UTF-32\((CFByteOrderGetCurrent() == CFByteOrderLittleEndian.rawValue) ? "LE" : "BE")"
                var hasBom:       Bool        = false

                buffer.initialize(repeating: 0, count: buffSize)
                defer { buffer.deinitialize(count: buffSize); buffer.deallocate() }
                let rc: Int = try inputStream.read(to: buffer, maxLength: buffSize)
                //-----------------------------------------------------------------------------------
                // No matter what it has to have at least 4 characters because the smallest possible
                // valid XML document is "<a/>" where "a" is any valid XML starting character. And
                // If it was encoded in UTF-32 we would at least get the "<" character even if the
                // BOM was missing.
                //-----------------------------------------------------------------------------------
                guard rc >= 4 else { throw SAXError.UnexpectedEndOfInput }

                if cmp1(buffer, count: 4, data: UTF32LEBOM) {
                    encoding = "UTF-32"; hasBom = true
                }
                else if cmp1(buffer, count: 4, data: UTF32BEBOM) {
                    encoding = "UTF-32"; hasBom = true
                }
                else if cmp1(buffer, count: 2, data: UTF16LEBOM) {
                    encoding = "UTF-16"; hasBom = true
                }
                else if cmp1(buffer, count: 2, data: UTF16BEBOM) {
                    encoding = "UTF-16"; hasBom = true
                }
                //-------------------------------------------------
                // There is no BOM so try to guess the byte order.
                //-------------------------------------------------
                else if buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0 {
                    encoding = "UTF-32BE"
                }
                else if buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0 {
                    encoding = "UTF-32LE"
                }
                else if (buffer[0] == 0 && buffer[1] != 0) || (buffer[2] == 0 && buffer[3] != 0) {
                    encoding = "UTF-16BE"
                }
                else if (buffer[0] != 0 && buffer[1] == 0) || (buffer[2] != 0 && buffer[3] == 0) {
                    encoding = "UTF-16LE"
                }
                else {
                    //----------------------------
                    // Default to UTF-8 encoding.
                    //----------------------------
                    encoding = "UTF-8"
                }

                //--------------------------------------------------------------------------------
                // Without an XML Declaration at the beginning of the XML document the only valid
                // character encodings are UTF-8, UTF-16, and UTF-32. So now we will see if there
                // is an XML Declaration telling us that it's something different.
                //--------------------------------------------------------------------------------
                inputStream.markRelease()
                inputStream.markSet()

                let charStream: IConvCharInputStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: encoding)
                var chars:      [Character]          = []

                charStream.open()
                try charStream.read(chars: &chars, maxLength: 5)
                let str = String(chars)

                if str == "<?xml" {
                    while let ch = try charStream.read() {
                        if ch == ">" && chars.last! == "?" {
                            chars.append(ch)
                            break
                        }
                        chars.append(ch)
                    }

                    let decl: String = String(chars)
                    print("XML Decl: \"\(decl)")
                    let regex = try RegEx(pattern: "^\\<\\?xml\\s+version=\"([^\"]+)\"(?:\\s+encoding=\"([^\"]+)\")?(?:\\s+standalone=\"([^\"]+)\")?\\s*\\?\\>")
                }
            }

            return handler
        }
    }

    final func cmp1(_ buffer: BytePointer, count: Int, data: [UInt8]) -> Bool {
        guard data.count >= count else { return false }
        for i in (0 ..< count) {
            if buffer[i] != data[i] { return false }
        }
        return true
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
