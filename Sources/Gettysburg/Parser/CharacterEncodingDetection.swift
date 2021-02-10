/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: CharacterEncodingDetection.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/8/21
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

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// 99.99999% of the time the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding is going to be UTF-8 - which is the default for XML.
    /// But the XML specification allows for other <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encodings as well so we have to try to
    /// detect what kind it really is.
    /// 
    /// The [XML specification states](https://www.w3.org/TR/REC-xml/#charencoding):
    /// 
    /// > Each external parsed entity in an XML document may use a different encoding for its characters. All XML processors must be able to read entities in both the UTF-8 and
    /// UTF-16 encodings. The terms "UTF-8" and "UTF-16" in this specification do not apply to related character encodings, including but not limited to UTF-16BE, UTF-16LE, or
    /// CESU-8.
    /// 
    /// > Entities encoded in UTF-16 must and entities encoded in UTF-8 may begin with the Byte Order Mark described by Annex H of [ISO/IEC 10646:2000], section 16.8 of [Unicode]
    /// (https://home.unicode.org) (the ZERO WIDTH NO-BREAK SPACE character, #xFEFF). This is an encoding signature, not part of either the markup or the character data of the XML
    /// document. XML processors must be able to use this character to differentiate between UTF-8 and UTF-16 encoded documents.
    /// 
    /// > If the replacement text of an external entity is to begin with the character U+FEFF, and no text declaration is present, then a Byte Order Mark MUST be present, whether
    /// the entity is encoded in UTF-8 or UTF-16.
    /// 
    /// > Although an XML processor is required to read only entities in the UTF-8 and UTF-16 encodings, it is recognized that other encodings are used around the world, and it
    /// may be desired for XML processors to read entities that use them. In the absence of external character encoding information (such as MIME headers), parsed entities which
    /// are stored in an encoding other than UTF-8 or UTF-16 must begin with a text declaration (see 4.3.1 The Text Declaration) containing an encoding declaration
    /// 
    /// In short, we're supposed to start out assuming the possibility of UTF-8 or UTF-16 and then if there is an XML Declaration we should see the encoding field in that, if it
    /// has one, to determine the actual character encoding used in the document.
    /// 
    /// Gettysburg will actually attempt to detect and handle UTF-8, UTF-16, and UTF-32 character encodings (with or without a byte-order-mark). Gettysburg will also handle other
    /// character encodings as long as there is an [XML Declaration](https://www.w3.org/TR/REC-xml/#sec-prolog-dtd) in the document specifying what the proper character encoding
    /// should be. That XML Declaration should be in either UTF-8, UTF-16, or UTF-32 encoding. Also, the encoding specified in the XML Declaration should match the byte-width of
    /// the XML Declaration itself. In other words, don't start off with UTF-16 and then specify UTF-8 in the XML Declaration. Even if everything AFTER the XML Declaration is in
    /// UTF-8 this is considered a malformed and invalid XML document.
    /// 
    /// The same applies to external entities and DTDs (which are considered a special case of external entities). Character encodings other than UTF-8, UTF-16, and UTF-32 will be
    /// supported as long as there is a [Text Declaration (XML specification sections 4.3.1 - 4.3.3)](https://www.w3.org/TR/REC-xml/#sec-TextDecl) at the beginning of the external
    /// entity or DTD.
    /// 
    /// - Parameter xmlDecl: the `XMLDecl` tuple.
    /// - Returns: the character input stream based on the determined character encoding.
    /// - Throws: if an I/O error occurred or the character encoding could not be determined or is unsupported.
    ///
    func setupXMLFileEncoding(xmlDecl: inout XMLDecl) throws -> CharInputStream {
        (xmlDecl.encoding, xmlDecl.endianBom) = try detectFileEncoding()

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
        if String(chars) == "<?xml" {
            return try parseXMLDeclaration(try getXMLDecl(tCharStream), chStream: tCharStream, xmlDecl: &xmlDecl)
        }

        //-----------------------------------------------------------------------------------
        // Otherwise there is no XML Declaration so we stick with what we have and continue.
        //-----------------------------------------------------------------------------------
        inputStream.markDelete()
        tCharStream.markReturn()
        return tCharStream
    }

    /*===========================================================================================================================================================================*/
    /// Parse the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) read from the document.
    /// 
    /// - Parameters:
    ///   - declString: the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) read from the document.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - xmlDecl: the current [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    /// - Returns: either the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> or a new one if it was determined that
    ///            it needed to change <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding.
    /// - Throws: if an error occurred or if there was a problem with the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    ///
    fileprivate func parseXMLDeclaration(_ declString: String, chStream: CharInputStream, xmlDecl: inout XMLDecl) throws -> CharInputStream {
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

        //------------------------------------------------------------------
        // We have what looks like a valid XML Declaration. So let's
        // parse it out, validate the data, and populate the xmlDecl tuple.
        //------------------------------------------------------------------
        if let match: RegularExpression.Match = regex.firstMatch(in: declString) {
            return try parseXMLDeclValues(&xmlDecl, match, declString, chStream)
        }
        //---------------------------------------------------------------
        // The XML Declaration we got is malformed and cannot be parsed.
        //---------------------------------------------------------------
        throw SAXError.InvalidXMLDeclaration(charStream, description: "The XML Declaration string is malformed: \"\(declString)\"")
    }

    /*===========================================================================================================================================================================*/
    /// Parse out the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the XML Document and populate the fields of our assumed xmlDecl tuple.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) values.
    ///   - match: the RegularExpression.Match object from our RegularExpression test.
    ///   - declString: the full text of the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    ///   - chStream: the current (detected) <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> or a new one if the
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding had to change.
    /// - Throws: if the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document was malformed or the newly declared
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding found in it is unsupported.
    ///
    fileprivate func parseXMLDeclValues(_ xmlDecl: inout XMLDecl, _ match: RegularExpression.Match, _ declString: String, _ chStream: CharInputStream) throws -> CharInputStream {
        //---------------------
        // Isolate the fields.
        //---------------------
        let values = try getXMLDeclFields(match)
        //---------------------------------------------------------------
        // Look for the version. At the very least that should be there.
        //---------------------------------------------------------------
        try parseXMLDeclVersion(&xmlDecl, declString, values)
        //------------------------------------
        // Now look for the "standalone" key.
        //------------------------------------
        try parseXMLDeclStandalone(&xmlDecl, values)
        //---------------------------------------------------------------------------------------
        // Now look for the "encoding" key and change the character stream's encoding if needed.
        //---------------------------------------------------------------------------------------
        return try parseXMLDeclEncoding(&xmlDecl, chStream, values)
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML `version` from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document. If the [XML
    /// Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) exists in the document then it has to at least have the `version`.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - declString: the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    ///   - values: the values from that [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// - Throws: if the `version` is incorrect.
    ///
    fileprivate func parseXMLDeclVersion(_ xmlDecl: inout XMLDecl, _ declString: String, _ values: [String: String]) throws {
        guard let declVersion = values["version"] else { throw SAXError.InvalidXMLDeclaration(charStream, description: "The version is missing from the XML Declaration: \"\(declString)\"") }
        guard (declVersion == "1.0") || (declVersion == "1.1") else { throw SAXError.InvalidXMLVersion(charStream, description: "The version stated in the XML Declaration is unsupported: \"\(declVersion)\"") }
        xmlDecl.version = declVersion
        xmlDecl.versionSpecified = true
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML `standalone` field, if it exists, from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - values: the values found in the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) in the document.
    /// - Throws: if the value for `standalone` is not `yes` or `no`.
    ///
    fileprivate func parseXMLDeclStandalone(_ xmlDecl: inout XMLDecl, _ values: [String: String]) throws {
        if let declStandalone = values["standalone"] {
            //--------------------------------------------------------
            // If it is there then it has to be either "yes" or "no".
            //--------------------------------------------------------
            guard value(declStandalone, isOneOf: "yes", "no") else { throw SAXError.InvalidXMLDeclaration(charStream, description: "Invalid argument for standalone: \"\(declStandalone)\"") }

            xmlDecl.standalone = (declStandalone == "yes")
            xmlDecl.standaloneSpecified = true
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML encoding from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document. If an encoding is found that is
    /// different than the detected encoding then create a new <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> and return that
    /// one.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - chStream: the current (detected) <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - values: the values from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    /// - Returns: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> unless a different encoding was declared in the
    ///            [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) in which case a new <code>[character input
    ///            stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> with that encoding is returned.
    /// - Throws: if the newly declared <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding is not supported.
    ///
    fileprivate func parseXMLDeclEncoding(_ xmlDecl: inout XMLDecl, _ chStream: CharInputStream, _ values: [String: String]) throws -> CharInputStream {
        if let declEncoding = values["encoding"] {
            if declEncoding.uppercased() != xmlDecl.encoding {
                let willChange = try isChangeReal(declEncoding: declEncoding, xmlDecl: xmlDecl)

                xmlDecl.encoding = declEncoding
                xmlDecl.encodingSpecified = true

                if willChange {
                    return try changeEncoding(xmlDecl: xmlDecl, chStream: chStream)
                }
            }

            xmlDecl.encoding = declEncoding
            xmlDecl.encodingSpecified = true
        }

        //--------------------------------------------------------------------------------
        // There is no change to the encoding so we stick with what we have and continue.
        //--------------------------------------------------------------------------------
        inputStream.markDelete()
        chStream.markDelete()
        return chStream
    }

    /*===========================================================================================================================================================================*/
    /// Changes the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to match the encoding that we found in the [XML
    /// Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// 
    /// - Parameters:
    ///   - xmlDecl: the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - chStream: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the new <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the new encoding is not supported by the installed version of libiconv.
    ///
    fileprivate func changeEncoding(xmlDecl decl: XMLDecl, chStream oChStream: CharInputStream) throws -> CharInputStream {
        let nEnc: String = decl.encoding.uppercased()
        //-----------------------------------------------------------------------
        // Close the old [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and reset the byte input stream.
        //-----------------------------------------------------------------------
        oChStream.close()
        inputStream.markReturn()
        //--------------------------------------------------------------
        // Now check to make sure we have support for the new encoding.
        //--------------------------------------------------------------
        guard IConv.getEncodingsList().contains(nEnc) else {
            //--------------------------------------------------
            // The encoding found in the XML Declaration is not
            // supported by the installed version of libiconv.
            //--------------------------------------------------
            throw SAXError.InvalidFileEncoding(charStream, description: "The file encoding in the XML Declaration is not supported: \"\(decl.encoding)\"")
        }
        //----------------------------------------------------------------------------
        // We have support for the new encoding so open a new character input stream.
        //----------------------------------------------------------------------------
        let nChStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: nEnc)
        nChStream.open()
        //----------------------------------------------------------------------------------
        // Now read past the XML Declaration since we don't need to parse it a second time.
        //----------------------------------------------------------------------------------
        var lc: Character = " "
        while let ch = try nChStream.read() {
            if ch == ">" && lc == "?" { return nChStream }
            lc = ch
        }
        throw SAXError.UnexpectedEndOfInput(nChStream)
    }

    /*===========================================================================================================================================================================*/
    /// The declared encoding is different than what we guessed at so now let's see if we really have to change or if it's simply a variation of what we guessed.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values including what we guessed was the encoding.
    ///   - declEncoding: the encoding specified in the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// - Returns: `true` if we really have to change the encoding or `false` if we can continue with what we have.
    /// - Throws: `SAXError.InvalidFileEncoding` if the declared byte order is definitely NOT what we encountered in the file.
    ///
    fileprivate func isChangeReal(declEncoding: String, xmlDecl: XMLDecl) throws -> Bool {
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
            if xmlDecl.endianBom == Endian.getEndianBySuffix(dEnc) { return false }
            let msg = "The byte order detected in the file does not match the byte order in the XML Declaration: \(xmlDecl.endianBom) != \(Endian.getEndianBySuffix(dEnc))"
            throw SAXError.InvalidXMLDeclaration(description: msg)
        }

        return true
    }

    /*===========================================================================================================================================================================*/
    /// The the fields out of a regex match of the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// 
    /// - Parameter match: the match object.
    /// - Returns: The map of fields and values.
    /// - Throws: if there was a duplicate field.
    ///
    fileprivate func getXMLDeclFields(_ match: RegularExpression.Match) throws -> [String: String] {
        var values: [String: String] = [:]
        for i: Int in stride(from: 1, to: 7, by: 2) {
            if let key = match[i].subString, let val = match[i + 1].subString {
                let k = key.trimmed
                guard values[k] == nil else { throw SAXError.InvalidXMLDeclaration(charStream, description: "The XML Declaration contains duplicate fields. First duplicate field encountered: \"\(k)\"") }
                values[k] = val.trimmed
            }
        }
        return values
    }

    /*===========================================================================================================================================================================*/
    /// Without an [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) at the beginning of the XML document the only valid
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encodings are UTF-8, UTF-16, and UTF-32. But before we can read enough of the document
    /// to tell if we even have an [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) we first have to try to determine the
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> width by looking at the first 4 bytes of data. This should tell us if we're looking at
    /// 8-bit (UTF-8), 16-bit (UTF-16), or 32-bit (UTF-32) <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// 
    /// - Returns: the name of the detected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding and the detected endian if it is a
    ///            multi-byte <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding.
    /// - Throws: SAXError or I/O <code>[Error](https://developer.apple.com/documentation/swift/error/)</code>.
    ///
    fileprivate func detectFileEncoding() throws -> (String, Endian) {
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
        guard rc == 4 else { throw SAXError.UnexpectedEndOfInput(1, 1) }

        //-----------------------------------------
        // Don't change the order of these tests.
        //-----------------------------------------
        // Start by looking for a byte order mark.
        //-----------------------------------------
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

    /*===========================================================================================================================================================================*/
    /// Read the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) from the XML document.
    /// 
    /// - Parameter charStream: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> stream to read the declaration from.
    /// - Returns: a <code>[String](https://developer.apple.com/documentation/swift/String)</code> containing the [XML
    ///            Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// - Throws: if the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) is malformed of if the EOF was encountered before the end of the [XML
    ///           Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) was reached.
    ///
    fileprivate func getXMLDecl(_ cStream: IConvCharInputStream) throws -> String {
        let s = try doRead(charInputStream: cStream) { ch, buffer in
            if ch == ">" {
                if let p = buffer.last, p == "?" { return true }
                throw SAXError.InvalidXMLDeclaration(charStream, description: "XML Declaration is invalid: \"<?xml>\"")
            }
            buffer <+ ch
            return false
        }
        return "<?xml\(s)>"
    }
}
