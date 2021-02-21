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

    /// Parse and handle a processing instruction.
    ///
    /// - Throws: if there is an I/O error or the processing instruction is malformed.
    ///
    func parseProcessingInstruction() throws {
        charStream.markSet()
        defer { charStream.markDelete() }
        let str = try charStream.readUntil(found: "?>")
        let rx  = try RegularExpression(pattern: "\\A(?s)([\(rxNameCharSet)]+)\\s+(.+?)\\?\\>\\z")
        guard let match = rx.firstMatch(in: str) else { throw SAXError.MalformedProcessingInstruction(charStream, description: "<?\(str)") }
        handler.processingInstruction(self, target: (match[1].subString ?? ""), data: (match[2].subString ?? ""))
    }

    /// Parse the XML Declaration if there is one. The XML Declaration is a special case of a processing instruction.
    ///
    /// - Throws: if an I/O error occurs or the XML Declaration is malformed.
    ///
    func parseXMLDecl() throws {
        charStream.markSet()
        defer { charStream.markReturn() }

        var xmlVersion:    String? = nil
        var xmlEncoding:   String? = nil
        var xmlStandalone: Bool?   = nil
        let str:           String  = try charStream.readString(count: 6, errorOnEOF: false)

        if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
            let xmlDecl = try charStream.readUntil(found: "?", ">")
            charStream.markUpdate()

            #if DEBUG
                print("\(xmlDecl)")
            #endif

            let regex = try RegularExpression(pattern: "\\A\\<\\?(?i:xml)\\s+version=\"([^\"]*)\"(?:\\s+encoding=\"([^\"]*)\")?(?:\\s+standalone=\"([^\"]*)\")?\\s*\\?\\>\\z")
            guard let match = regex.firstMatch(in: xmlDecl) else { throw SAXError.MalformedXMLDecl(charStream, description: xmlDecl) }

            if let s = match[1].subString {
                guard value(s, isOneOf: "1.0", "1.1") else { throw SAXError.MalformedXMLDecl(charStream, description: "Unsupported version: \(s)") }
                xmlVersion = s
            }

            if let s = match[2].subString {
                guard s != "" else { throw SAXError.MalformedXMLDecl(charStream, description: "Missing encoding value.") }
                xmlEncoding = s
            }

            if let s = match[3].subString {
                guard value(s, isOneOf: "yes", "no") else { throw SAXError.MalformedXMLDecl(charStream, description: "Invalid standalone value: \(s)") }
                xmlStandalone = (s == "yes")
            }

            #if DEBUG
                print("   XML Version: \(xmlVersion ?? "")")
                print("  XML Encoding: \(xmlEncoding ?? "")")
                print("XML Standalone: \(xmlStandalone ?? true)")
            #endif
        }

        self.xmlVersion = (xmlVersion ?? "1.0")
        self.xmlEncoding = (xmlEncoding ?? charStream.encodingName)
        self.xmlStandalone = (xmlStandalone ?? true)
    }
}
