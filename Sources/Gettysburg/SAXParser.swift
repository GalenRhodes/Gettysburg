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
#if os(Windows)
    import WinSDK
#endif

/*===============================================================================================================================================================================*/
/// An implementation of a SAX parser.
///
open class SAXParser<H: SAXHandler> {

    public internal(set) var url:          String
    public internal(set) var handler:      H?      = nil
    public internal(set) var xmlVersion:   String? = nil
    public internal(set) var xmlEncoding:  String? = nil
    public internal(set) var isStandalone: Bool?   = nil

    @inlinable final public var lineNumber:   Int { charStream.lineNumber }
    @inlinable final public var columnNumber: Int { charStream.columnNumber }

    public var allowedURIPrefixes: [String] = []
    public var willValidate:       Bool     = false

    @usableFromInline let inputStream:       MarkInputStream
    @usableFromInline var charStream:        CharInputStream!      = nil
    @usableFromInline var lock:              RecursiveLock         = RecursiveLock()
    @usableFromInline var foundRootElement:  Bool                  = false
    @usableFromInline var foundDTD:          Bool                  = false
    @usableFromInline var namespaceMappings: [NamespaceURIMapping] = []

    /*===========================================================================================================================================================================*/
    /// Create an instance of this parser from the given input stream.
    /// 
    /// - Parameters:
    ///   - inputStream: the <code>[InputStream](https://developer.apple.com/documentation/foundation/InputStream)</code>
    ///   - url: the URL where this document is located. If none is provided then a generic one will be generated.
    ///   - handler: an instance of a class that implements the `SAXHandler` protocol that will handle the messages sent from this parser.
    ///
    public init(inputStream: InputStream, url: String = "uuid:\(UUID().uuidString).xml", handler: H? = nil) {
        self.handler = handler
        self.inputStream = MarkInputStream(inputStream: inputStream)
        self.url = url
    }

    /*===========================================================================================================================================================================*/
    /// Set the instance of the class that implements `SAXHandler` that will handle the parsing messages sent from this parser.
    /// 
    /// - Parameter handler: the handler.
    /// - Returns: this parser.
    /// - Throws: if the handler had already been set previously.
    ///
    @discardableResult public final func set(handler: H) throws -> SAXParser<H> {
        guard self.handler == nil else { throw SAXError.HandlerAlreadySet() }
        self.handler = handler
        return self
    }

    /*===========================================================================================================================================================================*/
    /// Set the willValidate flag.
    /// 
    /// - Parameter flag: if `true` this parser will perform validation based on the DTD provided in the document. If `false` no validation will be performed.
    /// - Returns: this parser.
    ///
    @discardableResult open func set(willValidate flag: Bool) -> SAXParser<H> {
        willValidate = flag
        return self
    }

    /*===========================================================================================================================================================================*/
    /// Set the list of allowed URI prefixes for resolving external entities and DocTypes.
    /// 
    /// - Parameters:
    ///   - uris: the list of URI prefixes.
    ///   - append: if `true` the list will be added to any already set. If `false` (the default) the list provided here will completely replace what is already there.
    /// - Returns: this parser.
    ///
    @discardableResult open func set(allowedUriPrefixes uris: [String], append: Bool = false) -> SAXParser<H> {
        if append { allowedURIPrefixes.append(contentsOf: uris) }
        else { allowedURIPrefixes = uris }
        return self
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML document.
    /// 
    /// - Returns: The handler used to parse the document.
    /// - Throws: if an I/O error occurs or if the XML document is malformed.
    ///
    @discardableResult open func parse() throws -> H {
        try lock.withLock { () -> H in
            guard let handler = handler else { throw SAXError.MissingHandler() }

            do {
                var xmlDecl: XMLDecl = ("1.0", false, "UTF-8", false, .None, true, false)

                if inputStream.streamStatus == .notOpen { inputStream.open() }
                //------------------------------------------------
                // Try to determine the encoding of the XML file.
                //------------------------------------------------
                charStream = try setupXMLFileEncoding(xmlDecl: &xmlDecl)
                defer { charStream.close() }
                // FIXME: If the char stream didn't change then we still have a mark on it at this point.
                xmlVersion = xmlDecl.version
                xmlEncoding = xmlDecl.encoding
                isStandalone = xmlDecl.standalone

                handler.documentBegin(parser: self,
                                      version: (xmlDecl.versionSpecified ? xmlDecl.version : nil),
                                      encoding: (xmlDecl.encodingSpecified ? xmlDecl.encoding : nil),
                                      standAlone: (xmlDecl.standaloneSpecified ? xmlDecl.standalone : nil))
                try parseDocumentRoot(handler)
                handler.documentEnd(parser: self)
            }
            catch let e {
                handler.parseErrorOccurred(parser: self, error: e)
                throw e
            }

            return handler
        }
    }
}
