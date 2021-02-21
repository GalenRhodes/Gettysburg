/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
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

open class SAXParser {

    public enum ExternalEntityResolvingPolicy {
        case always
        case never
        case noNetwork
        case sameOriginOnly
    }

    public var lineNumber:   Int { ((charStream == nil) ? 1 : charStream.lineNumber) }
    public var columnNumber: Int { ((charStream == nil) ? 1 : charStream.columnNumber) }
    public var baseURL:      URL { ((charStream == nil) ? url.deletingLastPathComponent() : charStream.baseURL) }
    public var filename:     String { ((charStream == nil) ? url.lastPathComponent : charStream.filename) }

    /// This value is not valid until after parsing has started.
    public internal(set) var xmlVersion:    String = ""
    /// This value is not valid until after parsing has started.
    public internal(set) var xmlEncoding:   String = ""
    /// This value is not valid until after parsing has started.
    public internal(set) var xmlStandalone: Bool   = true

    public var allowedExternalEntityURLs:     Set<String>                   = []
    public var externalEntityResolvingPolicy: ExternalEntityResolvingPolicy = .always

    var charStream:  SAXCharInputStream! = nil
    let inputStream: MarkInputStream
    let handler:     SAXHandler
    let url:         URL

    init(inputStream: InputStream, url: URL? = nil, handler: SAXHandler) throws {
        self.inputStream = ((inputStream as? MarkInputStream) ?? MarkInputStream(inputStream: inputStream))
        self.handler = handler
        self.url = (url?.absoluteURL ?? getFileURL(filename: "\(UUID().uuidString).xml"))
    }

    func createCharStream() throws {
        charStream = try SAXCharInputStream(inputStream: inputStream, url: url)
        charStream.open()
    }

    /// Parse the document.
    ///
    /// - Throws: if an I/O error occurs or the document is malformed.
    ///
    open func parse() throws {
        try createCharStream()
        defer { charStream.close() }

        try parseXMLDecl()
        handler.beginDocument(self)
        //-------------------------------
        // Now parse out the document...
        //-------------------------------
        try parseDocument()
        //-----------------------------------------
        // We're finished so let the handler know.
        //-----------------------------------------
        handler.endDocument(self)
    }
}
