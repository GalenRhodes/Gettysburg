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

let DefMemLimit: Int = (1024 * 1024)
let MinMemLimit: Int = 4096
let MaxMemLimit: Int = (DefMemLimit * 4)

open class SAXParser {

    public enum ExternalEntityResolvingPolicy {
        case always
        case never
        case noNetwork
        case sameOriginOnly
    }

    //@f:0
    public var position:                      TextPosition                  { charStream.position     }
    public var baseURL:                       URL                           { charStream.baseURL      }
    public var filename:                      String                        { charStream.filename     }

    public var allowedExternalEntityURLs:     Set<String>                   = []
    public var externalEntityResolvingPolicy: ExternalEntityResolvingPolicy = .always

    /*===========================================================================================================================================================================*/
    /// This value is not valid until after parsing has started.
    ///
    public               var xmlEncoding:   String { charStream.encodingName }
    /*===========================================================================================================================================================================*/
    /// This value is not valid until after parsing has started.
    ///
    public internal(set) var xmlVersion:    String = ""
    /*===========================================================================================================================================================================*/
    /// This value is not valid until after parsing has started.
    ///
    public internal(set) var xmlStandalone: Bool   = true

    /*===========================================================================================================================================================================*/
    /// For performance, SAXParser tries to read as much of an XML structure into memory and then analyze it as a whole. This setting limits the number of characters read at once
    /// to keep memory from being exhausted. If this limit is hit then an error is thrown. Normal text blocks, including CDATA sections are "chunked" if they exceed this limit so
    /// that no error is thrown. Except for text blocks, this limit should never be breached for a well formed document. Allowed range is 4KB <= limit <= 4MB. The default is 1MB.
    ///
    let memLimit:    Int                       = DefMemLimit
    let docType:     SAXDTD                    = SAXDTD()
    var charStream:  SAXParserCharInputStream! = nil
    let handler:     SAXHandler

    var url:         URL                       { charStream.url }
    //@f:1

    public init(inputStream: InputStream, url: URL? = nil, handler: SAXHandler) throws {
        self.handler = handler
        self.charStream = try SAXParserCharInputStream(inputStream: inputStream, url: (url ?? GetFileURL(filename: "inputstream_\(UUID().uuidString).xml")), parser: self)
    }

    public convenience init(filename: String, handler: SAXHandler) throws {
        guard let strm = InputStream(fileAtPath: filename) else { throw StreamError.FileNotFound(description: filename) }
        try self.init(inputStream: strm, url: GetFileURL(filename: filename), handler: handler)
    }

    public convenience init(url: URL, handler: SAXHandler) throws {
        guard let strm = InputStream(url: url) else { throw StreamError.FileNotFound(description: url.description) }
        try self.init(inputStream: strm, url: url, handler: handler)
    }

    public convenience init(data: Data, url: URL? = nil, handler: SAXHandler) throws {
        try self.init(inputStream: InputStream(data: data), url: (url ?? GetFileURL(filename: "data_\(UUID().uuidString).xml")), handler: handler)
    }

    public convenience init(string: String, url: URL? = nil, handler: SAXHandler) throws {
        let data: Data = Data(string.utf8)
        try self.init(inputStream: InputStream(data: data), url: (url ?? GetFileURL(filename: "string_\(UUID().uuidString).xml")), handler: handler)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the document.
    ///
    /// - Throws: if an I/O error occurs or the document is malformed.
    ///
    open func parse() throws {
        charStream.open()
        defer { charStream.close() }

        try parseXMLDecl(charStream)
        handler.beginDocument(self)
        //-------------------------------
        // Now parse out the document...
        //-------------------------------
        try parseDocument(charStream)
        //-----------------------------------------
        // We're finished so let the handler know.
        //-----------------------------------------
        handler.endDocument(self)
    }
}
