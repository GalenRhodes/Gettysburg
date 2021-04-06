/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ProcessingInstruction.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/18/21
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

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Parse and handle a processing instruction.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there is an I/O error or the processing instruction is malformed.
    ///
    func parseProcessingInstruction(_ chStream: SAXCharInputStream) throws {
        chStream.markSet()
        defer { chStream.markDelete() }
        let str = try chStream.readUntil(found: "?>")
        guard let rx = RegularExpression(pattern: "\\A(?s)([\(rxNameCharSet)]+)\\s+(.+?)\\?\\>\\z") else { throw SAXError.IOError(chStream, description: "Bad Regex") }
        guard let match = rx.firstMatch(in: str) else { throw SAXError.MalformedProcessingInstruction(chStream, description: "<?\(str)") }

        let target = (match[1].subString ?? "")
        guard target.lowercased() != "xml" else { throw SAXError.MalformedProcessingInstruction(chStream, description: "XML Declaration not allowed here.") }

        handler.processingInstruction(self, target: target, data: (match[2].subString ?? ""))
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML Declaration if there is one. The XML Declaration is a special case of a processing instruction.
    /// 
    /// - Throws: if an I/O error occurs or the XML Declaration is malformed.
    ///
    func parseXMLDecl(_ chStream: SAXCharInputStream) throws {
        let data = try parseXMLDecl(chStream, mustHave: .Version)
        xmlVersion = (data.version ?? "1.0")
        xmlEncoding = (data.encoding ?? chStream.encodingName)
        xmlStandalone = (data.standalone ?? true)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML Declaration if there is one. The XML Declaration is a special case of a processing instruction.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to read the XML Declaration from.
    /// - Returns: a tuple with the parsed version, encoding, and standalone flag.
    /// - Throws: if an I/O error occurs or the XML Declaration is malformed.
    ///
    func parseXMLDecl(_ chStream: SAXCharInputStream, mustHave: XMLDeclEnum...) throws -> XMLDeclData {
        var data: XMLDeclData = (nil, nil, nil)

        chStream.markSet()
        let str = try chStream.readString(count: 6, errorOnEOF: false)

        if str.count == 6 {
            if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
                try parseXMLDeclBody(chStream, data: &data)
            }
            else if try str.matches(pattern: "\\A\\<\\?(?i:xml)\\?") {
                try chStream.readChar(mustBeOneOf: ">")
            }
            else if try str.matches(pattern: "\\A\\<\\?(?i:xml)."), let lc = str.last {
                return try foo(chStream, lastChar: lc, data: data)
            }

            chStream.markDelete()
            return try testMustHaves(data: data, chStream: chStream, mustHave: mustHave)
        }

        return foo2(chStream, data: data)
    }

    /*===========================================================================================================================================================================*/
    /// Foo
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - lc: the last character read.
    ///   - data: the XML Declaration data.
    /// - Returns: the XML Declaration data.
    /// - Throws: if there was an I/O error or the XML Declaration was malformed.
    ///
    private func foo(_ chStream: SAXCharInputStream, lastChar lc: Character, data: XMLDeclData) throws -> XMLDeclData {
        guard lc.isXmlNameChar else { throw SAXError.InvalidCharacter(chStream, found: lc, expected: XML_WS_CHAR_DESCRIPTION + [ "?" ]) }
        return foo2(chStream, data: data)
    }

    /*===========================================================================================================================================================================*/
    /// Foo2
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - data: the XML Declaration data.
    /// - Returns: the XML Declaration data.
    ///
    private func foo2(_ chStream: SAXCharInputStream, data: XMLDeclData) -> XMLDeclData {
        chStream.markReturn()
        return data
    }

    /*===========================================================================================================================================================================*/
    /// Parse the body of the XML Declaration.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - data: the XML Declaration data.
    /// - Throws: if the XML Declaration is malformed or there is an I/O error.
    ///
    private func parseXMLDeclBody(_ chStream: SAXCharInputStream, data: inout XMLDeclData) throws {
        var nextCh = try chStream.skipWhitespace(mustHave: false)
        repeat {
            guard nextCh != "?" else { try chStream.readChars(mustBe: "?>"); break }
            guard nextCh.isXmlNameStartChar else { throw SAXError.InvalidCharacter(chStream, found: nextCh) }

            let p = try chStream.readKeyValuePair(leadingWS: .None)
            try handleXMLDeclParameter(chStream, data: &data, param: p)
            nextCh = try chStream.peek()

            if nextCh != "?" { nextCh = try chStream.skipWhitespace(mustHave: true) }
        }
        while true
    }

    /*===========================================================================================================================================================================*/
    /// Test to make sure that the XML Declaration has the required parameters.
    /// 
    /// - Parameters:
    ///   - data: the XML Declaration data.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - mustHave: the list of must have parameters.
    /// - Returns: the XML Declaration data.
    /// - Throws: if the XML Declaration is missing parameters.
    ///
    private func testMustHaves(data: XMLDeclData, chStream: SAXCharInputStream, mustHave: [XMLDeclEnum]) throws -> XMLDeclData {
        for mh in mustHave {
            switch mh {
                case .Version:    if data.version == nil { throw valueRequiredError(chStream, mh) }
                case .Encoding:   if data.encoding == nil { throw valueRequiredError(chStream, mh) }
                case .Standalone: if data.standalone == nil { throw valueRequiredError(chStream, mh) }
            }
        }
        return data
    }

    /*===========================================================================================================================================================================*/
    /// Handle an XML Declaration parameter.
    /// 
    /// - Parameters:
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - data: the XML Declaration data.
    ///   - key: the parameter name.
    ///   - val: the parameter value.
    /// - Throws: if the parameter is unknown or has already been encountered.
    ///
    private func handleXMLDeclParameter(_ chStream: SAXCharInputStream, data: inout XMLDeclData, param: KVPair) throws {
        let key = param.key
        let val = param.value.lowercased()

        switch key {
            case XMLDeclEnum.Version.rawValue:
                try checkForDuplicate(chStream, parameterName: key, xmlDeclValue: data.version)
                guard value(val, isOneOf: "1.0", "1.1") else { throw SAXError.MalformedXMLDecl(chStream, description: "Unsupported XML Version: \"\(val)\"") }
                data.version = val
            case XMLDeclEnum.Encoding.rawValue:
                try checkForDuplicate(chStream, parameterName: key, xmlDeclValue: data.encoding)
                guard IConv.encodingsList.contains(where: { val ==~ $0 }) else { throw SAXError.MalformedXMLDecl(chStream, description: "Unsupported Character Encoding: \"\(val)\"") }
                data.encoding = val
            case XMLDeclEnum.Standalone.rawValue:
                let msg3 = "Value for parameter \"\(key)\" must be \"\(true)\" or \"\(false)\""
                try checkForDuplicate(chStream, parameterName: key, xmlDeclValue: data.standalone)
                guard value(val, isOneOf: true.description, false.description) else { throw SAXError.MalformedXMLDecl(chStream, description: "\(msg3): \"\(val)\"") }
                data.standalone = (val == true.description)
            default:
                throw SAXError.MalformedXMLDecl(chStream, description: "Unknown parameter: \"\(key)\"")
        }
    }

    private func checkForDuplicate(_ chStream: SAXCharInputStream, parameterName key: String, xmlDeclValue val: Any?) throws {
        guard val == nil else { throw SAXError.MalformedXMLDecl(chStream, description: "Duplicate parameter: \"\(key)\"") }
    }

    private func valueRequiredError(_ chStream: SAXCharInputStream, _ mh: XMLDeclEnum) -> SAXError.MalformedXMLDecl {
        SAXError.MalformedXMLDecl(chStream, description: "Parameter \"\(mh.rawValue)\" is required.")
    }
}
