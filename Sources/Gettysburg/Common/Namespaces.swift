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

/*===============================================================================================================================*/
/// Holds a qualified name.
///
@frozen public struct QName: Hashable, Comparable, CustomStringConvertible, Codable {
    private enum CodingKeys: CodingKey { case prefix, localName }

    //@f:0
    public               var prefix:      String? = nil
    public internal(set) var localName:   String
    @inlinable public    var description: String  { qName }
    @inlinable public    var qName:       String  { prefix == nil ? localName : "\(prefix!):\(localName)" }
    //@f:1

    public init(prefix: String?, localName: String) {
        guard localName.trimmed.isNotEmpty else { fatalError("Empty local name.") }
        if let p = prefix?.trimmed, p.isNotEmpty { self.prefix = p }
        self.localName = localName.trimmed
    }

    public init(qName: String) {
        guard qName.trimmed.isNotEmpty else { fatalError("Empty qualified name.") }

        if let idx = qName.firstIndex(where: { $0 == ":" }) {
            self.init(prefix: ((idx > qName.startIndex) ? String(qName[qName.startIndex ..< idx]) : nil), localName: String(qName[qName.index(after: idx) ..< qName.endIndex]))
        }
        else {
            self.init(prefix: nil, localName: qName)
        }
    }

    public init(name: String) { self.init(prefix: nil, localName: name) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prefix = try c.decodeIfPresent(String.self, forKey: .prefix)
        localName = try c.decode(String.self, forKey: .localName)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(prefix, forKey: .prefix)
        try c.encode(localName, forKey: .localName)
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
    private enum CodingKeys: CodingKey { case name, uri }

//@f:0
    public internal(set) var localName:   String  { get { _name.localName } set { _name.localName = newValue } }
    public internal(set) var prefix:      String? { get { _name.prefix }    set { _name.prefix = newValue }    }
    public internal(set) var uri:         String?
    @inlinable public    var description: String  { _name.description }
//@f:1

    @usableFromInline var _name: QName

    public init(localName: String, prefix: String? = nil, namespaceURI uri: String?) {
        if let u = uri, u.trimmed.isNotEmpty {
            self._name = QName(prefix: prefix, localName: localName)
            self.uri = u
        }
        else {
            self._name = QName(prefix: nil, localName: localName)
            self.uri = nil
        }
    }

    public init(name: String) {
        self.init(localName: name, prefix: nil, namespaceURI: nil)
    }

    public init(qName: String, namespaceURI uri: String) {
        guard uri.trimmed.isNotEmpty else { fatalError("Empty namespace URI") }
        self._name = QName(qName: qName)
        self.uri = uri
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _name = try c.decode(QName.self, forKey: .name)
        uri = try c.decodeIfPresent(String.self, forKey: .uri)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(_name, forKey: .name)
        try c.encode(uri, forKey: .uri)
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(_name)
        hasher.combine(uri)
    }

    @inlinable public static func < (lhs: NSName, rhs: NSName) -> Bool { areLessThan((lhs._name.localName, rhs._name.localName), (lhs.uri, rhs.uri)) }

    @inlinable public static func == (lhs: NSName, rhs: NSName) -> Bool { areEqual((lhs._name.localName, rhs._name.localName), (lhs.uri, rhs.uri)) }
}

/*===============================================================================================================================*/
/// Holds a `prefix` to `uri` mapping.
///
@frozen public struct NSMapping: Hashable, Comparable, CustomStringConvertible, Codable {
    private enum CodingKeys: CodingKey { case prefix, namespaceURI }

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.prefix = try c.decode(String.self, forKey: .prefix)
        self.namespaceURI = try c.decode(String.self, forKey: .namespaceURI)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(prefix, forKey: .prefix)
        try c.encode(namespaceURI, forKey: .namespaceURI)
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(prefix)
        hasher.combine(namespaceURI)
    }

    @inlinable public static func == (lhs: Self, rhs: Self) -> Bool { areEqual((lhs.prefix, rhs.prefix), (lhs.namespaceURI, rhs.namespaceURI)) }

    @inlinable public static func < (lhs: Self, rhs: Self) -> Bool { areLessThan((lhs.prefix, rhs.prefix), (lhs.namespaceURI, rhs.namespaceURI)) }
}
