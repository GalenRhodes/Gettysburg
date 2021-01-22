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

    typealias XMLDecl = (version: String, versionSpecified: Bool, encoding: String, encodingSpecified: Bool, endianBom: EndianBOM, standalone: Bool, standaloneSpecified: Bool)

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
            var xmlDecl: XMLDecl = ("1.0", false, "UTF-8", false, .None, true, false)

            guard let handler = handler else { throw SAXError.MissingHandler() }
            if inputStream.streamStatus == .notOpen { inputStream.open() }

            //------------------------------------------------
            // Try to determine the encoding of the XML file.
            //------------------------------------------------
            charStream = try setupXMLFileEncoding(xmlDecl: &xmlDecl)
            handler.documentBegin(parser: self,
                                  version: (xmlDecl.versionSpecified ? xmlDecl.version : nil),
                                  encoding: (xmlDecl.encodingSpecified ? xmlDecl.encoding : nil),
                                  standAlone: (xmlDecl.standaloneSpecified ? xmlDecl.standalone : nil))

            handler.documentEnd(parser: self)
            return handler
        }
    }

    /*===========================================================================================================================================================================*/
    /// 99.99999% of the time the character encoding is going to be UTF-8 - which is the default. But the XML specification allows for other character encodings as well so we have
    /// to try to detect what kind it really is.
    /// 
    /// - Parameter xmlDecl:
    /// - Returns:
    /// - Throws:
    ///
    final func setupXMLFileEncoding(xmlDecl: inout XMLDecl) throws -> CharInputStream {
        (xmlDecl.encoding, xmlDecl.endianBom) = try detectFileEncoding()
        #if DEBUG
            print("Charset Encoding: \(xmlDecl.encoding); Endian BOM: \(xmlDecl.endianBom)")
        #endif
        //--------------------------------------------------------------------------------
        // So now we will see if there
        // is an XML Declaration telling us that it's something different.
        //--------------------------------------------------------------------------------
        inputStream.markSet()

        var chars:       [Character]          = []
        let tCharStream: IConvCharInputStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: xmlDecl.encoding)

        tCharStream.open()
        tCharStream.markSet()

        //-------------------------------------------------------------------------------------------------------
        // If we have an XML Declaration, parse it and see if it says something different than what we detected.
        //-------------------------------------------------------------------------------------------------------
        _ = try tCharStream.read(chars: &chars, maxLength: 5)
        if String(chars) == "<?xml" { return try parseXMLDeclaration(try getXMLDecl(tCharStream), chStream: tCharStream, xmlDecl: &xmlDecl) }
        //-----------------------------------------------------------------------------------
        // Otherwise there is no XML Declaration so we stick with what we have and continue.
        //-----------------------------------------------------------------------------------
        inputStream.markRelease(discard: true)
        tCharStream.markRelease()
        return tCharStream
    }

    final func parseXMLDeclaration(_ declString: String, chStream: CharInputStream, xmlDecl: inout XMLDecl) throws -> CharInputStream {
        //--------------------------------------------------------------------------------------------------
        // Now, normally the fields "version", "encoding", and "standalone" have to be in that exact order.
        // But we're going to be a little lax and not really care as long as only those three fields are
        // there. However, we are going to stick to the requirement that "version" has to be there. The
        // other two fields are optional. Also, each field can only be there once. In other words, for
        // example, the "standalone" field cannot exist twice.
        //--------------------------------------------------------------------------------------------------
        let sx    = "version|encoding|standalone"
        let sy    = "\\s+(\(sx))=\"([^\"]+)\""
        let regex = try RegularExpression(pattern: "^\\<\\?xml\(sy)(?:\(sy))?(?:\(sy))?\\s*\\?\\>")

        #if DEBUG
            print("XML Decl: \"\(declString)")
        #endif

        if let match: RegularExpression.Match = regex.firstMatch(in: declString) {
            let values = try getXMLDeclFields(match)
            //---------------------------------------------------------------
            // Look for the version. At the very least that should be there.
            //---------------------------------------------------------------
            guard let declVersion = values["version"] else { throw SAXError.InvalidXMLDeclaration(description: "The version is missing from the XML Declaration: \"\(declString)\"") }
            guard declVersion == "1.0" || declVersion == "1.1" else { throw SAXError.InvalidXMLVersion(description: "The version stated in the XML Declaration is unsupported: \"\(declVersion)\"") }

            xmlDecl.version = declVersion
            xmlDecl.versionSpecified = true

            //------------------------------------
            // Now look for the "standalone" key.
            //------------------------------------
            if let declStandalone = values["standalone"] {
                //--------------------------------------------------------
                // If it is there then it has to be either "yes" or "no".
                //--------------------------------------------------------
                guard declStandalone == "yes" || declStandalone == "no" else { throw SAXError.InvalidXMLDeclaration(description: "Invalid argument for standalone: \"\(declStandalone)\"") }

                xmlDecl.standalone = (declStandalone == "yes")
                xmlDecl.standaloneSpecified = true
            }

            if let de = values["encoding"] {
                let declEncoding = de.uppercased()

                if declEncoding != xmlDecl.encoding {
                    #if DEBUG
                        print("New Encoding Specified: \"\(declEncoding)\"")
                    #endif
                    let willChange = try isChangeReal(xmlDecl: xmlDecl, declEncoding: declEncoding)
                    xmlDecl.encoding = declEncoding
                    xmlDecl.encodingSpecified = true
                    if willChange { return try changeEncoding(xmlDecl: xmlDecl, chStream: chStream) }
                }

                xmlDecl.encoding = declEncoding
                xmlDecl.encodingSpecified = true
            }

            //--------------------------------------------------------------------------------
            // There is no change to the encoding so we stick with what we have and continue.
            //--------------------------------------------------------------------------------
            inputStream.markRelease(discard: true)
            return chStream
        }

        //---------------------------------------------------------------
        // The XML Declaration we got is malformed and cannot be parsed.
        //---------------------------------------------------------------
        throw SAXError.InvalidXMLDeclaration(description: "The XML Declaration string is malformed: \"\(declString)\"")
    }

    func changeEncoding(xmlDecl: XMLDecl, chStream: CharInputStream) throws -> CharInputStream {
        chStream.close()
        inputStream.markRelease()
        //--------------------------------------------------------------------
        // What we detected is different than what we got so let's switch it.
        //--------------------------------------------------------------------
        let iconvList = IConv.getEncodingsList()
        let nEnc      = xmlDecl.encoding.uppercased()
        for enc in iconvList { if enc == nEnc { return try skimOverXMLDecl(chStream: IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: enc)) } }
        throw SAXError.InvalidFileEncoding(description: "The file encoding stated in the XML Declaration is not supported: \"\(xmlDecl.encoding)\"")
    }

    func skimOverXMLDecl(chStream: CharInputStream) throws -> CharInputStream {
        chStream.open()
        //-------------------------------------------------------------------------
        // Seems redundant but in this case we need to re-read the XML Declaration
        // just to get it out of the way.
        //-------------------------------------------------------------------------
        var c = [ Character ]()
        while let ch = try chStream.read() {
            if ch == ">" && !c.isEmpty && c.last! == "?" { return chStream }
            c.append(ch)
        }
        throw SAXError.UnexpectedEndOfInput()
    }

    func isChangeReal(xmlDecl: XMLDecl, declEncoding: String) throws -> Bool {
        let badBOMMsg = "The byte order detected in the file does not match the byte order specified in the XML Declaration."

        switch xmlDecl.encoding {
            case "UTF-16BE":
                if declEncoding == "UTF-16LE" { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if declEncoding != "UTF-16" { return true }
            case "UTF-16LE":
                if declEncoding == "UTF-16BE" { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if declEncoding != "UTF-16" { return true }
            case "UTF-32BE":
                if declEncoding == "UTF-32LE" { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if declEncoding != "UTF-32" { return true }
            case "UTF-32LE":
                if declEncoding == "UTF-32BE" { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if declEncoding != "UTF-32" { return true }
            case "UTF-16":
                if declEncoding == "UTF-16LE" && xmlDecl.endianBom == .BigEndian { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if declEncoding == "UTF-16BE" && xmlDecl.endianBom == .LittleEndian { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if !declEncoding.hasPrefix("UTF-16") { return true }
            case "UTF-32":
                if declEncoding == "UTF-32LE" && xmlDecl.endianBom == .BigEndian { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if declEncoding == "UTF-32BE" && xmlDecl.endianBom == .LittleEndian { throw SAXError.InvalidFileEncoding(description: badBOMMsg) }
                if !declEncoding.hasPrefix("UTF-32") { return true }
            default:
                return true
        }
        return false
    }

    func getXMLDeclFields(_ match: RegularExpression.Match) throws -> [String: String] {
        var values: [String: String] = [:]
        for i: Int in stride(from: 1, to: 7, by: 2) {
            if let key = match[i].subString, let val = match[i + 1].subString {
                let k = key.trimmed
                guard values[k] == nil else { throw SAXError.InvalidXMLDeclaration(description: "The XML Declaration contains duplicate fields. First duplicate field encountered: \"\(k)\"") }
                values[k] = val.trimmed
            }
        }
        return values
    }

    /*===========================================================================================================================================================================*/
    /// Without an XML Declaration at the beginning of the XML document the only valid character encodings are UTF-8, UTF-16, and UTF-32. But before we can read enough of the
    /// document to tell if we even have an XML Declaration we first have to try to determine the character width by looking at the first 4 bytes of data. This should tell us if
    /// we're looking at 8-bit (UTF-8), 16-bit (UTF-16), or 32-bit (UTF-32) characters.
    /// 
    /// - Returns: the name of the detected character encoding and the detected endian if it is a multi-byte character encoding.
    /// - Throws: SAXError or I/O <code>[Error](https://developer.apple.com/documentation/swift/error/)</code>.
    ///
    final func detectFileEncoding() throws -> (String, EndianBOM) {
        inputStream.markSet()
        defer { inputStream.markRelease() }

        let buffSize: Int         = 4
        let buffer:   BytePointer = BytePointer.allocate(capacity: buffSize)

        buffer.initialize(repeating: 0, count: buffSize)
        defer {
            buffer.deinitialize(count: buffSize)
            buffer.deallocate()
        }

        let rc: Int = try inputStream.read(to: buffer, maxLength: buffSize)
        //-----------------------------------------------------------------------------------
        // No matter what it has to have at least 4 characters because the smallest possible
        // valid XML document is "<a/>" where "a" is any valid XML starting character. And
        // If it was encoded in UTF-32 we would at least get the "<" character even if the
        // BOM was missing.
        //-----------------------------------------------------------------------------------
        guard rc >= 4 else { throw SAXError.UnexpectedEndOfInput() }

        if cmp1(buffer, count: 4, data: UTF32LEBOM) { return ("UTF-32", .LittleEndian) }
        else if cmp1(buffer, count: 4, data: UTF32BEBOM) { return ("UTF-32", .BigEndian) }
        else if cmp1(buffer, count: 2, data: UTF16LEBOM) { return ("UTF-16", .LittleEndian) }
        else if cmp1(buffer, count: 2, data: UTF16BEBOM) { return ("UTF-16", .BigEndian) }
        //-------------------------------------------------
        // There is no BOM so try to guess the byte order.
        //-------------------------------------------------
        else if buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0 { return ("UTF-32BE", .None) }
        else if buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0 { return ("UTF-32LE", .None) }
        else if (buffer[0] == 0 && buffer[1] != 0) || (buffer[2] == 0 && buffer[3] != 0) { return ("UTF-16BE", .None) }
        else if (buffer[0] != 0 && buffer[1] == 0) || (buffer[2] != 0 && buffer[3] == 0) { return ("UTF-16LE", .None) }
        //----------------------------
        // Default to UTF-8 encoding.
        //----------------------------
        return ("UTF-8", .None)
    }

    final func getXMLDecl(_ charStream: IConvCharInputStream) throws -> String {
        var chars: [Character] = []

        if let c1 = try charStream.read() {
            guard c1 != ">" else { throw SAXError.InvalidXMLVersion(description: "The XML Declaration string is malformed: \"<?xml>\"") }

            chars <+ c1
            while let c2 = try charStream.read() {
                if c2 == ">" && chars.last! == "?" { return "<?xml\(String(chars))>" }
                chars <+ c2
            }
        }

        throw SAXError.InvalidXMLVersion(description: "Unexpected end of input. The XML Declaration is incomplete: \"<?xml \(String(chars))\"")
    }

    final func cmp1(_ buffer: BytePointer, count: Int, data: [UInt8]) -> Bool {
        guard data.count >= count else { return false }
        for i in (0 ..< count) {
            if buffer[i] != data[i] { return false }
        }
        return true
    }

    @discardableResult public final func set(handler: H) throws -> SAXParser<H> {
        guard self.handler == nil else { throw SAXError.HandlerAlreadySet() }
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

    enum EndianBOM {
        case None
        case LittleEndian
        case BigEndian
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

extension SAXParser.EndianBOM: CustomStringConvertible {
    var description: String {
        switch self {
            case .None:         return "N/A"
            case .LittleEndian: return "Little Endian"
            case .BigEndian:    return "Big Endian"
        }
    }
}
