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

public struct SAXNSName: Hashable {

    public let localName: String
    public let prefix:    String?
    public var uri:       String?

    @inlinable var name: String { ((uri != nil && prefix != nil) ? "\(prefix!):\(localName)" : localName) }

    @inlinable init(localName: String, prefix: String?, uri: String?) {
        self.localName = localName
        self.prefix = ((uri == nil) ? nil : prefix)
        self.uri = uri
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(localName)
        hasher.combine(prefix)
    }

    @inlinable public static func == (lhs: SAXNSName, rhs: SAXNSName) -> Bool {
        lhs.localName == rhs.localName && lhs.prefix == rhs.prefix
    }
}

/*===============================================================================================================================================================================*/
/// Holds a `prefix` to `uri` mapping.
///
public struct NSMapping: Hashable {
    public let prefix: String
    public let uri:    String

    @inlinable init(prefix: String, uri: String) {
        self.prefix = prefix
        self.uri = uri
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(prefix)
        hasher.combine(uri)
    }

    @inlinable public static func == (lhs: NSMapping, rhs: NSMapping) -> Bool {
        lhs.prefix == rhs.prefix && lhs.uri == rhs.uri
    }
}
