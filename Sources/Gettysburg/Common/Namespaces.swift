/*
 *     PROJECT: Gettysburg
 *    FILENAME: Namespaces.swift
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

public typealias NamespaceTuple = (localName: String, namespaceURI: String)

@inlinable public func == (lhs: NamespaceTuple, rhs:NamespaceTuple) -> Bool { areEqual((lhs.localName, rhs.localName), (lhs.namespaceURI, rhs.namespaceURI)) }

@inlinable public func < (lhs: NamespaceTuple, rhs: NamespaceTuple) -> Bool { areLessThan((lhs.localName, rhs.localName), (lhs.namespaceURI, rhs.namespaceURI)) }

/*===============================================================================================================================*/
/// Holds a qualified name.
///
@frozen public struct QName: Hashable, Comparable, CustomStringConvertible, Codable {
    public var prefix:    String? = nil
    public let localName: String

    @inlinable public var description: String { qName }
    @inlinable public var qName:       String {
        guard let p = prefix else { return localName }
        return "\(p):\(localName)"
    }

    @inlinable public init(prefix: String?, localName: String) {
        if let p = prefix { self.prefix = (p.isEmpty ? nil : p) }
        self.localName = localName
    }

    @inlinable public init<S>(qName: S) where S: StringProtocol {
        if let idx = qName.firstIndex(where: { $0 == ":" }) {
            self.localName = String(qName[qName.index(after: idx) ..< qName.endIndex])
            self.prefix = ((idx > qName.startIndex) ? String(qName[qName.startIndex ..< idx]) : nil)
        }
        else {
            self.prefix = nil
            self.localName = String(qName)
        }
    }

    @inlinable public init<S>(name: S) where S: StringProtocol {
        localName = name
        prefix = nil
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(prefix)
        hasher.combine(localName)
    }

    @inlinable public static func < (lhs: QName, rhs: QName) -> Bool { areLessThan((lhs.localName, rhs.localName), (lhs.prefix, rhs.prefix)) }

    @inlinable public static func == (lhs: QName, rhs: QName) -> Bool { areEqual((lhs.localName, rhs.localName), (lhs.prefix, rhs.prefix)) }
}

/*===============================================================================================================================*/
/// Holds a qualified namespace name along with it's associated URI.
///
@frozen public struct NSName: Hashable, Comparable, CustomStringConvertible, Codable {

    public var name: QName
    public let uri:  String?

    @inlinable public var description: String { name.description }

    @inlinable init(localName: String, prefix: String? = nil, namespaceURI uri: String?) {
        if let u = uri {
            self.name = QName(prefix: prefix, localName: localName)
            self.uri = u
        }
        else {
            self.name = QName(prefix: nil, localName: localName)
            self.uri = nil
        }
    }

    @inlinable init(name: String) {
        self.init(localName: name, prefix: nil, namespaceURI: nil)
    }

    @inlinable init(qName: String, namespaceURI uri: String) {
        self.name = QName(qName: qName)
        self.uri = uri
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(uri)
    }

    @inlinable public static func < (lhs: NSName, rhs: NSName) -> Bool { areLessThan((lhs.name.localName, rhs.name.localName), (lhs.uri, rhs.uri)) }

    @inlinable public static func == (lhs: NSName, rhs: NSName) -> Bool { areEqual((lhs.name.localName, rhs.name.localName), (lhs.uri, rhs.uri)) }
}

/*===============================================================================================================================*/
/// Holds a `prefix` to `uri` mapping.
///
@frozen public struct NSMapping: Hashable, Comparable, CustomStringConvertible, Codable {
    public let prefix:       String
    public let namespaceURI: String

    @inlinable public var description: String { isDefault ? "xmlns=\(namespaceURI.quoted())" : "xmlns:\(prefix)=\(namespaceURI.quoted())" }
    @inlinable public var isDefault:   Bool { prefix.isEmpty }

    @inlinable init?(attribute a: SAXRawAttribute) {
        if a.name.prefix == "xmlns" {
            self.prefix = a.name.localName
            self.namespaceURI = a.value
        }
        else if a.name.prefix == nil && a.name.localName == "xmlns" {
            self.prefix = ""
            self.namespaceURI = a.value
        }
        else {
            return nil
        }
    }

    @inlinable init(prefix: String, namespaceURI uri: String) {
        self.prefix = prefix.trimmed
        self.namespaceURI = uri
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(prefix)
        hasher.combine(namespaceURI)
    }

    @inlinable public static func == (lhs: Self, rhs: Self) -> Bool { areEqual((lhs.prefix, rhs.prefix), (lhs.namespaceURI, rhs.namespaceURI)) }

    @inlinable public static func < (lhs: Self, rhs: Self) -> Bool { areLessThan((lhs.prefix, rhs.prefix), (lhs.namespaceURI, rhs.namespaceURI)) }
}
