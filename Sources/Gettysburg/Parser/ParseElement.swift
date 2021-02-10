/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ParseElement.swift
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
    /// Parse and handle an element.
    /// 
    /// - Parameters:
    ///   - handler: the SAXHandler
    ///   - firstChar: the first <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the element name.
    /// - Throws: if there is an I/O error or the element is malformed.
    ///
    final func parseElement(_ handler: H) throws {
        let name              = try readXmlName()
        let (isClosed, attrs) = try readElementInfo()

        if !isClosed {
            // TODO: Parse Element...
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the element opening tag.
    /// 
    /// - Returns: a tuple containing the boolean indicating if this is an open or close element and any attributes contained in the element tag.
    /// - Throws: if there is an I/O error or the element is malformed.
    ///
    final func readElementInfo() throws -> (Bool, [SAXParsedAttribute]) {
        var rawAttrs: [String: String] = [:]

        while let ch = try charStream.read() {
            if ch == "/" {
                try readCharAnd(expected: ">")
                return (true, try processAttributes(attributes: rawAttrs))
            }
            else if ch == ">" {
                return (false, try processAttributes(attributes: rawAttrs))
            }
            else if ch.isXmlNameStartChar {
                markBackup()
                let attr = try readAttribute()
            }
            else if !ch.isXmlWhitespace {
                throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg(ch))
            }
        }

        throw SAXError.UnexpectedEndOfInput(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the body of the element. That would be everything between "<tagname>" and "</tagname>".
    /// 
    /// - Parameters:
    ///   - handler: the SAX Handler.
    ///   - elementName: the name of the element.
    ///   - attributes: the attributes of the element.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or something in the body is malformed.
    ///
    final func parseElementBody(_ handler: H, elementName: String, attributes: [SAXParsedAttribute]) throws {
        // TODO: Parse Element Body...
    }

    /*===========================================================================================================================================================================*/
    /// Process the elements attributes.
    /// 
    /// - Parameter rawAttrs: the raw attribute data.
    /// - Returns: an <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> of `SAXParsedAttribute`.
    /// - Throws: if an I/O error occurs or if the attributes are malformed.
    ///
    final func processAttributes(attributes rawAttrs: [String: String]) throws -> [SAXParsedAttribute] {
        func foo01(_ ns: (prefix: String?, localName: String), _ uri: String, _ value: String, _ attrs: inout [SAXParsedAttribute]) {
            namespaceMappings <+ NamespaceURIMapping(namespaceURI: value)
            attrs <+ SAXParsedAttribute(localName: ns.localName, prefix: ns.prefix, namespaceURI: uri, defaulted: false, value: value)
        }

        var attrs: [SAXParsedAttribute] = []

        //-----------------------------------------
        // First process and namespace attributes.
        //-----------------------------------------
        for (name, value) in rawAttrs {
            let ns = name.getXmlPrefixAndLocalName()
            let f  = (ns.prefix == "xmlns")

            if f || ns.prefix == "xml" {
                if ns.localName.isEmpty { throw SAXError.NamespaceError(charStream, description: "Missing namespace prefix definition.") }
                foo01(ns, (f ? "http://www.w3.org/2000/xmlns/" : "http://www.w3.org/XML/1998/namespace"), value, &attrs)
            }
            else if ns.prefix == nil && ns.localName == "xmlns" {
                foo01(ns, "http://www.w3.org/2000/xmlns/", value, &attrs)
            }
        }

        //----------------------------------------
        // Then process the remaining attributes.
        //----------------------------------------
        for (name, value) in rawAttrs {
            let ns = name.getXmlPrefixAndLocalName()
            let f  = !(ns.prefix == "xml" || ns.prefix == "xmlns" || (ns.prefix == nil && ns.localName == "xmlns"))

            if f {
                let uri = (getNamespaceURI(prefix: (ns.prefix == nil) ? "" : ns.prefix!) ?? getNamespaceURI(prefix: ""))
                if uri == nil && ns.prefix != nil { throw SAXError.NamespaceError(charStream, description: "Missing namespace URI for prefix: \"\(ns.prefix ?? "")\"") }
                attrs <+ SAXParsedAttribute(localName: ns.localName, prefix: ns.prefix, namespaceURI: uri, defaulted: false, value: value)
            }
        }

        // TODO: Look for duplicate attribute names and throw an error.
        return attrs
    }

    /*===========================================================================================================================================================================*/
    /// Reach and attribute from the element tag body.
    /// 
    /// - Returns: instance of `NSAttribInfo` that contains the attribute information.
    /// - Throws: if an error occurs.
    ///
    final func readAttribute() throws -> NSAttribInfo {
        markSet()
        defer { markDelete() }

        let line        = charStream.lineNumber
        let column      = charStream.columnNumber
        let qName       = try readXmlName()
        let attrName    = qName.getXmlPrefixAndLocalName()
        let lcLocalName = attrName.localName.lowercased()
        let lcPrefix    = attrName.prefix?.lowercased()
        let noPrefix    = (lcPrefix == nil)

        try readCharAnd(expected: "=")
        if !noPrefix && lcLocalName.isEmpty { markReset(); throw SAXError.NamespaceError(charStream, description: "Local name is missing: \"\(qName)\"") }
        if !(noPrefix && lcLocalName == "xmlns") {
            if lcLocalName.hasPrefix("xml") { markReset(); throw SAXError.NamespaceError(charStream, description: "Invalid local name: \"\(qName)\"") }
        }

        markUpdate()
        try readCharAnd(expected: "\"")
        let attrValue = try readAttributeValue()
        let noValue   = attrValue.trimmed.isEmpty

        if ((noPrefix && lcLocalName == "xmlns") || lcPrefix == "xmlns" || lcPrefix == "xml") && noValue { markReset(); throw SAXError.NamespaceError(charStream, description: "Missing namespace URI.") }

        return NSAttribInfo(line: line, column: column, prefix: attrName.prefix, localName: attrName.localName, value: attrValue)
    }

    /*===========================================================================================================================================================================*/
    /// Reads the attributes value from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> input stream.
    /// 
    /// - Returns: the attributes value.
    /// - Throws: if an I/O error occurs or if there are illegal <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the value.
    ///
    final func readAttributeValue() throws -> String {
        var chars: [Character] = []
        while let ch = try charStream.read() {
            switch ch {
                case "\"": return String(chars)
                case "<":  markBackup(); throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg(ch))
                case "&":  chars.append(contentsOf: try readAndResolveEntityReference())
                default:   chars <+ ch
            }
        }
        throw SAXError.UnexpectedEndOfInput(charStream)
    }
}
