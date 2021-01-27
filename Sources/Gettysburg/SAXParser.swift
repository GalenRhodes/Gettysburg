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

    public internal(set) var url:          String
    public internal(set) var handler:      H?      = nil
    public internal(set) var xmlVersion:   String? = nil
    public internal(set) var xmlEncoding:  String? = nil
    public internal(set) var isStandalone: Bool?   = nil

    @inlinable final public var lineNumber:   Int { charStream.lineNumber }
    @inlinable final public var columnNumber: Int { charStream.columnNumber }

    public var allowedURIPrefixes: [String] = []
    public var willValidate:       Bool     = false

    @usableFromInline let inputStream: MarkInputStream
    @usableFromInline var charStream:  CharInputStream! = nil
    @usableFromInline lazy var lock: RecursiveLock = RecursiveLock()

    @usableFromInline var foundRootElement: Bool = false

    public init(inputStream: InputStream, url: String, handler: H? = nil) {
        self.handler = handler
        self.inputStream = MarkInputStream(inputStream: inputStream)
        self.url = url
    }

    @discardableResult public final func set(handler: H) throws -> SAXParser<H> {
        guard self.handler == nil else { throw getSAXError_HandlerAlreadySet() }
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

    @discardableResult open func parse() throws -> H {
        try lock.withLock { () -> H in
            guard let handler = handler else { throw getSAXError_MissingHandler() }

            do {
                var xmlDecl: XMLDecl = ("1.0", false, "UTF-8", false, .None, true, false)

                if inputStream.streamStatus == .notOpen { inputStream.open() }

                //------------------------------------------------
                // Try to determine the encoding of the XML file.
                //------------------------------------------------
                charStream = try setupXMLFileEncoding(xmlDecl: &xmlDecl)
                defer { charStream.close() }

                xmlVersion = xmlDecl.version
                xmlEncoding = xmlDecl.encoding
                isStandalone = xmlDecl.standalone

                handler.documentBegin(parser: self,
                                      version: (xmlDecl.versionSpecified ? xmlDecl.version : nil),
                                      encoding: (xmlDecl.encodingSpecified ? xmlDecl.encoding : nil),
                                      standAlone: (xmlDecl.standaloneSpecified ? xmlDecl.standalone : nil))
                try parseDocument(handler)
                handler.documentEnd(parser: self)
            }
            catch let e {
                handler.parseErrorOccurred(parser: self, error: e)
                throw e
            }

            return handler
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse out the main body of the XML Document that includes the root element and DOCTYPES as well as any processing instructions, whitespace, and comments that might exist
    /// at the root level.
    ///
    /// - Throws: `SAXError` or any I/O errors.
    ///
    func parseDocument(_ handler: H) throws {
        charStream.markSet()
        defer { charStream.markDelete() }

        while var ch = try charStream.read() {
            if ch == "<" {
                var chars: [Character] = []

                charStream.markSet()
                do {
                    defer { charStream.markDelete() }

                    if try charStream.read(chars: &chars, maxLength: 9) == 9 {
                        let str = String(chars)

                        if try str.matches(pattern: "\\!DOCTYPE\\s") {
                            try parseDocType(handler)
                        }
                        else if str.hasPrefix("!--") {
                            charStream.markReset()
                            guard try charStream.read(chars: &chars, maxLength: 3) == 3 else { throw getSAXError_UnexpectedEndOfInput() }
                            try parseComment(handler)
                        }
                    }
                }
            }
            else if ch.isWhitespace {
                repeat {
                    charStream.markUpdate()
                    guard let c = try charStream.read() else {
                        charStream.markDelete()
                        return
                    }
                    ch = c
                }
                while ch.isWhitespace
                charStream.markReset()
            }
            else {
                charStream.markReset()
                throw getSAXError_InvalidCharacter("Character \"\(ch)\" not expected here.")
            }

            charStream.markUpdate()
        }
    }

    func parseComment(_ handler: H) throws {
        var comment: [Character] = []

        while let ch = try charStream.read() {
            if comment.count > 1 && comment[comment.count - 1] == "-" && comment[comment.count - 2] == "-" {
                guard ch == ">" else { throw getSAXError_InvalidCharacter("Comments cannot contain double dashes.") }
                comment.removeLast(2)
                handler.comment(parser: self, comment: String(comment))
                return
            }
            else {
                comment <+ ch
            }
        }

        throw getSAXError_UnexpectedEndOfInput()
    }

    func parseDocType(_ handler: H) throws {
    }

    final func readWhitespace() throws -> String {
        var chars: [Character] = []
        charStream.markSet()

        while let ch = try charStream.read() {
            guard ch.isWhitespace else {
                charStream.markReturn()
                return String(chars)
            }
            chars <+ ch
            charStream.markUpdate()
        }

        charStream.markDelete()
        return String(chars)
    }

    final func readUntilWhitespace() throws -> String {
        var chars: [Character] = []
        charStream.markSet()

        while let ch = try charStream.read() {
            guard !ch.isWhitespace else {
                charStream.markReturn()
                return String(chars)
            }
            chars <+ ch
            charStream.markUpdate()
        }

        charStream.markDelete()
        return String(chars)
    }

    final func readUntil(marker: String, dropMarker: Bool = true, leaveFPatMarker: Bool = false) throws -> String {
        var chars: [Character] = []
        let _mrkr: [Character] = getCharacters(marker)

        while chars.count < _mrkr.count {
            guard let ch = try charStream.read() else { throw getSAXError_UnexpectedEndOfInput() }
            chars <+ ch
        }

        while !cmpSuffix(suffix: _mrkr, source: chars) {
            guard let ch = try charStream.read() else { throw getSAXError_UnexpectedEndOfInput() }
            chars <+ ch
        }

        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// This method returns an array of the individual characters of a string. It also breaks up grapheme clusters into their individual unicode code points.
    ///
    /// - Parameter str: the string.
    /// - Returns: the characters that make up the string.
    ///
    final func getCharacters(_ str: String) -> [Character] {
        var chars: [Character] = []
        for ch: Character in str {
            for sc: UnicodeScalar in ch.unicodeScalars {
                chars <+ Character(sc)
            }
        }
        return chars
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
        inputStream.markDelete()
        tCharStream.markReturn()
        return tCharStream
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML Declaration read from the document.
    ///
    /// - Parameters:
    ///   - declString: the XML Declaration read from the document.
    ///   - chStream: the character input stream.
    ///   - xmlDecl: the current XML Declaration values.
    /// - Returns: either the current character input stream or a new one if it was determined that it needed to change character encoding.
    /// - Throws: if an error occurred or if there was a problem with the XML Declaration.
    ///
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
            guard let declVersion = values["version"] else { throw getSAXError_InvalidXMLDeclaration("The version is missing from the XML Declaration: \"\(declString)\"") }
            guard declVersion == "1.0" || declVersion == "1.1" else { throw getSAXError_InvalidXMLVersion("The version stated in the XML Declaration is unsupported: \"\(declVersion)\"") }

            xmlDecl.version = declVersion
            xmlDecl.versionSpecified = true

            //------------------------------------
            // Now look for the "standalone" key.
            //------------------------------------
            if let declStandalone = values["standalone"] {
                //--------------------------------------------------------
                // If it is there then it has to be either "yes" or "no".
                //--------------------------------------------------------
                guard value(declStandalone, isOneOf: "yes", "no") else { throw getSAXError_InvalidXMLDeclaration("Invalid argument for standalone: \"\(declStandalone)\"") }

                xmlDecl.standalone = (declStandalone == "yes")
                xmlDecl.standaloneSpecified = true
            }

            if let declEncoding = values["encoding"] {
                if declEncoding.uppercased() != xmlDecl.encoding {
                    #if DEBUG
                        print("New Encoding Specified: \"\(declEncoding)\"")
                    #endif
                    let willChange = try isChangeReal(declEncoding: declEncoding, xmlDecl: xmlDecl)
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
            inputStream.markDelete()
            return chStream
        }

        //---------------------------------------------------------------
        // The XML Declaration we got is malformed and cannot be parsed.
        //---------------------------------------------------------------
        throw getSAXError_InvalidXMLDeclaration("The XML Declaration string is malformed: \"\(declString)\"")
    }

    /*===========================================================================================================================================================================*/
    /// Changes the character input stream to match the encoding that we found in the XML Declaration.
    ///
    /// - Parameters:
    ///   - xmlDecl: the XML Declaration values.
    ///   - chStream: the current character input stream.
    /// - Returns: the new character input stream.
    /// - Throws: if the new encoding is not supported by the installed version of libiconv.
    ///
    func changeEncoding(xmlDecl decl: XMLDecl, chStream chs: CharInputStream) throws -> CharInputStream {
        let nEnc: String = decl.encoding.uppercased()
        //-----------------------------------------------------------------------
        // Close the old character input stream and reset the byte input stream.
        //-----------------------------------------------------------------------
        chs.close()
        inputStream.markReturn()
        //--------------------------------------------------------------
        // Now check to make sure we have support for the new encoding.
        //--------------------------------------------------------------
        guard IConv.getEncodingsList().contains(nEnc) else {
            //--------------------------------------------------
            // The encoding found in the XML Declaration is not
            // supported by the installed version of libiconv.
            //--------------------------------------------------
            throw getSAXError_InvalidFileEncoding("The file encoding in the XML Declaration is not supported: \"\(decl.encoding)\"")
        }
        //----------------------------------------------------------------------------
        // We have support for the new encoding so open a new character input stream.
        //----------------------------------------------------------------------------
        let nChStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: nEnc)
        nChStream.open()
        //----------------------------------------------------------------------------------
        // Now read past the XML Declaration since we don't need to parse it a second time.
        //----------------------------------------------------------------------------------
        var c: Character = "<" // Doesn't matter the value as long as it's not a question mark.
        while let ch = try nChStream.read() {
            #if DEBUG
                print("\(ch)", terminator: "")
            #endif
            if ch == ">" && c == "?" {
                #if DEBUG
                    print("")
                #endif
                return nChStream
            }
            c = ch
        }
        #if DEBUG
            print("")
        #endif
        //------------------------------------------------------------------
        // We ran out of characters before we finished reading past the XML
        // Declaration so something went very wrong.
        //------------------------------------------------------------------
        throw SAXError.UnexpectedEndOfInput(nChStream.lineNumber, nChStream.columnNumber)
    }

    /*===========================================================================================================================================================================*/
    /// The declared encoding is different than what we guessed at so now let's see if we really have to change or if it's simply a variation of what we guessed.
    ///
    /// - Parameters:
    ///   - xmlDecl: the current XML Declaration values including what we guessed was the encoding.
    ///   - declEncoding: the encoding specified in the XML Declaration.
    /// - Returns: `true` if we really have to change the encoding or `false` if we can continue with what we have.
    /// - Throws: `SAXError.InvalidFileEncoding` if the declared byte order is definitely NOT what we encountered in the file.
    ///
    func isChangeReal(declEncoding: String, xmlDecl: XMLDecl) throws -> Bool {
        func foo(_ str: String) -> Bool { (str == "UTF-16" || str == "UTF-32") }

        let dEnc = declEncoding.uppercased()
        let xEnc = xmlDecl.encoding

        if xEnc == "UTF-8" {
            return true
        }
        else if foo(dEnc) {
            return !xEnc.hasPrefix(dEnc)
        }
        else if foo(xEnc) && dEnc.hasPrefix(xEnc) {
            if xmlDecl.endianBom == EndianBOM.getEndianBySuffix(dEnc) { return false }
            let msg = "The byte order detected in the file does not match the byte order in the XML Declaration: \(xmlDecl.endianBom) != \(EndianBOM.getEndianBySuffix(dEnc))"
            throw SAXError.InvalidXMLDeclaration(description: msg)
        }

        return true
    }

    func getXMLDeclFields(_ match: RegularExpression.Match) throws -> [String: String] {
        var values: [String: String] = [:]
        for i: Int in stride(from: 1, to: 7, by: 2) {
            if let key = match[i].subString, let val = match[i + 1].subString {
                let k = key.trimmed
                guard values[k] == nil else { throw getSAXError_InvalidXMLDeclaration("The XML Declaration contains duplicate fields. First duplicate field encountered: \"\(k)\"") }
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
        defer { inputStream.markReturn() }

        var buf: [UInt8] = []
        let rc:  Int     = try inputStream.read(to: &buf, maxLength: 4)

        //-----------------------------------------------------------------------------------
        // No matter what it has to have at least 4 characters because the smallest possible
        // valid XML document is "<a/>" where "a" is any valid XML starting character. And
        // if it was encoded in UTF-32 we would at least get the "<" character even if the
        // BOM was missing.
        //-----------------------------------------------------------------------------------
        guard rc == 4 else { throw SAXError.UnexpectedEndOfInput(0, 0) }

        if cmpPrefix(prefix: UTF32LEBOM, source: buf) { return ("UTF-32", .LittleEndian) }
        else if cmpPrefix(prefix: UTF32BEBOM, source: buf) { return ("UTF-32", .BigEndian) }
        else if cmpPrefix(prefix: UTF16LEBOM, source: buf) { return ("UTF-16", .LittleEndian) }
        else if cmpPrefix(prefix: UTF16BEBOM, source: buf) { return ("UTF-16", .BigEndian) }
        //-------------------------------------------------
        // There is no BOM so try to guess the byte order.
        //-------------------------------------------------
        else if buf[0] == 0 && buf[1] == 0 && buf[3] != 0 { return ("UTF-32BE", .None) }
        else if buf[0] != 0 && buf[2] == 0 && buf[3] == 0 { return ("UTF-32LE", .None) }
        else if (buf[0] == 0 && buf[1] != 0) || (buf[2] == 0 && buf[3] != 0) { return ("UTF-16BE", .None) }
        else if (buf[0] != 0 && buf[1] == 0) || (buf[2] != 0 && buf[3] == 0) { return ("UTF-16LE", .None) }
        //----------------------------
        // Default to UTF-8 encoding.
        //----------------------------
        return ("UTF-8", .None)
    }

    final func getXMLDecl(_ charStream: IConvCharInputStream) throws -> String {
        var chars: [Character] = []

        if let c1 = try charStream.read() {
            guard c1 != ">" else { throw getSAXError_InvalidXMLVersion("The XML Declaration string is malformed: \"<?xml>\"") }

            chars <+ c1
            while let c2 = try charStream.read() {
                if c2 == ">" && chars.last! == "?" { return "<?xml\(String(chars))>" }
                chars <+ c2
            }
        }

        throw getSAXError_InvalidXMLVersion("Unexpected end of input. The XML Declaration is incomplete: \"<?xml \(String(chars))\"")
    }

    @usableFromInline final func getSAXError_MissingHandler(_ desc: String? = nil) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        if let d = desc { return SAXError.MissingHandler(l, c, description: d) }
        else { return SAXError.MissingHandler(l, c) }
    }

    @usableFromInline final func getSAXError_HandlerAlreadySet(_ desc: String? = nil) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        if let d = desc { return SAXError.HandlerAlreadySet(l, c, description: d) }
        else { return SAXError.HandlerAlreadySet(l, c) }
    }

    @usableFromInline final func getSAXError_InvalidXMLVersion(_ desc: String? = nil) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        if let d = desc { return SAXError.InvalidXMLVersion(l, c, description: d) }
        else { return SAXError.InvalidXMLVersion(l, c) }
    }

    @usableFromInline final func getSAXError_InvalidFileEncoding(_ desc: String? = nil) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        if let d = desc { return SAXError.InvalidFileEncoding(l, c, description: d) }
        else { return SAXError.InvalidFileEncoding(l, c) }
    }

    @usableFromInline final func getSAXError_InvalidXMLDeclaration(_ desc: String? = nil) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        if let d = desc { return SAXError.InvalidXMLDeclaration(l, c, description: d) }
        else { return SAXError.InvalidXMLDeclaration(l, c) }
    }

    @usableFromInline final func getSAXError_InvalidCharacter(_ desc: String) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        return SAXError.InvalidCharacter(l, c, description: desc)
    }

    @usableFromInline final func getSAXError_UnexpectedEndOfInput(_ desc: String? = nil) -> SAXError {
        let l = charStream.lineNumber
        let c = charStream.columnNumber
        if let d = desc { return SAXError.UnexpectedEndOfInput(l, c, description: d) }
        else { return SAXError.UnexpectedEndOfInput(l, c) }
    }

    public enum EndianBOM {
        case None
        case LittleEndian
        case BigEndian
    }

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
    public var description: String {
        switch self {
            case .None:         return "N/A"
            case .LittleEndian: return "Little Endian"
            case .BigEndian:    return "Big Endian"
        }
    }

    @inlinable static func getEndianBOM(_ str: String?) -> Self {
        guard let str = str else { return .None }
        switch str.uppercased() {
            case "BE", "BIG", "BIGENDIAN", "BIG ENDIAN": return .BigEndian
            case "LE", "LITTLE", "LITTLEENDIAN", "LITTLE ENDIAN": return .LittleEndian
            default: return .None
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the endian by the encoding name's suffix.
    ///
    /// - Parameter str: the suffix.
    /// - Returns: the endian.
    ///
    ///
    @inlinable static func getEndianBySuffix(_ str: String?) -> Self {
        guard let str = str else { return .None }
        let s = str.uppercased()
        return (s.hasSuffix("BE") ? .BigEndian : (s.hasSuffix("LE") ? .LittleEndian : .None))
    }
}
