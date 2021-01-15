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
import Rubicon

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

    let inputStream: InputStream

    lazy var lock: RecursiveLock = RecursiveLock()

    public init(inputStream: InputStream, uri: String, handler: H? = nil) {
        self.handler = handler
        self.inputStream = inputStream
        self.uri = uri
    }

    @discardableResult open func parse() throws -> H {
        try lock.withLock { () -> H in
            guard let handler = handler else { throw SAXError.MissingHandler }

            return handler
        }
    }

    @discardableResult public final func set(handler: H) throws -> SAXParser<H> {
        guard self.handler == nil else { throw SAXError.HandlerAlreadySet }
        self.handler = handler
        return self
    }

    @discardableResult open func setValidation(willValidate: Bool) -> SAXParser<H> {
        self.willValidate = willValidate
        return self
    }

    @discardableResult open func setAllowedURIPrefixes(uriPrefixes: [String], append: Bool = false) -> SAXParser<H> {
        if append { allowedURIPrefixes.append(contentsOf: uriPrefixes) }
        else { allowedURIPrefixes = uriPrefixes }
        return self
    }
}
