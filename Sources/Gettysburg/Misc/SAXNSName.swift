/*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXNSName.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 3/8/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

public typealias SAXName = (prefix: String?, localName: String)

/*===============================================================================================================================================================================*/
/// Holds a qualified namespace name along with it's associated URI.
///
@frozen public struct SAXNSName: Hashable, Comparable, CustomStringConvertible {

    public let            localName:   String
    public let            prefix:      String?
    public let            uri:         String?
    @inlinable public var name:        String { ((uri != nil && prefix != nil) ? "\(prefix!):\(localName)" : localName) }
    @inlinable public var description: String { name }

    init(localName: String, prefix: String?, uri: String?) {
        self.localName = localName
        if uri == nil {
            self.prefix = nil
            self.uri = nil
        }
        else {
            self.prefix = prefix
            self.uri = uri
        }
    }

    init(name: String) {
        localName = name
        prefix = nil
        uri = nil
    }

    init(qName: String, uri: String?) {
        if uri == nil {
            self.uri = nil
            self.prefix = nil
            self.localName = qName
        }
        else {
            self.uri = uri
            (self.prefix, self.localName) = qName.splitPrefix()
        }
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(localName)
        hasher.combine(prefix)
        hasher.combine(uri)
    }

    public static func < (lhs: SAXNSName, rhs: SAXNSName) -> Bool {
        if let luri = lhs.uri, let lpfx = lhs.prefix, let ruri = rhs.uri, let rpfx = rhs.prefix {
            return ((lhs.localName < rhs.localName) || ((lhs.localName == rhs.localName) && (lpfx < rpfx)) || ((lhs.localName == rhs.localName) && (lpfx == rpfx) && (luri < ruri)))
        }
        else if let _ = lhs.uri, let _ = lhs.prefix {
            return false
        }
        else if let _ = rhs.uri, let _ = rhs.prefix {
            return true
        }
        else {
            return (lhs.localName < rhs.localName)
        }
    }

    @inlinable public static func == (lhs: SAXNSName, rhs: SAXNSName) -> Bool { ((lhs.localName == rhs.localName) && (lhs.prefix == rhs.prefix) && (lhs.uri == rhs.uri)) }
}

/*===============================================================================================================================================================================*/
/// Holds a `prefix` to `uri` mapping.
///
@frozen public struct NSMapping: Hashable, Comparable, CustomStringConvertible {
    public let            prefix:      String
    public let            uri:         String
    @inlinable public var description: String { isDefault ? "xmlns=\(uri.encodeEntities().quoted())" : "xmlns:\(prefix)=\(uri.encodeEntities().quoted())" }
    @inlinable public var isDefault:   Bool { prefix.isEmpty }

    init?(_ a: SAXRawAttribute) {
        if a.name.prefix == "xmlns" {
            self.prefix = a.name.localName
            self.uri = a.value
        }
        else if a.name.prefix == nil && a.name.localName == "xmlns" {
            self.prefix = ""
            self.uri = a.value
        }
        else {
            return nil
        }
    }

    init(prefix: String, uri: String) {
        self.prefix = prefix.trimmed
        self.uri = uri
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(prefix)
    }

    @inlinable public static func == (lhs: NSMapping, rhs: NSMapping) -> Bool { (lhs.prefix == rhs.prefix) }

    @inlinable public static func < (lhs: NSMapping, rhs: NSMapping) -> Bool { (lhs.prefix < rhs.prefix) }
}
