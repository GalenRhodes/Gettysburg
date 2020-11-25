/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ElementInfo.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/24/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
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

private func findURI(name: NSName, elem: ElementInfo) -> String? {
    if let pfx = name.prefix {
        for ((p, l, _), sp) in elem.attributes {
            if p == "xmlns" && l == pfx { return sp.string }
        }
    }
    else {
        for ((p, l, _), sp) in elem.attributes {
            if p == nil && l == "xmlns" { return sp.string }
        }
    }
    return nil
}

public struct ElementInfo: Hashable {
    let tagName:      NSName
    var namespaceURI: String? = nil
    let attributes:   [NSAttribute]

    public init(tagName: NSName, stack: [ElementInfo], attributes: [NSAttribute]) {
        self.tagName = tagName
        self.attributes = attributes
        namespaceURI = findURI(name: tagName, elem: self)

        if namespaceURI == nil {
            for elem in stack.reversed() {
                namespaceURI = findURI(name: tagName, elem: elem)
                if namespaceURI != nil { break }
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tagName.localName)
        hasher.combine(tagName.prefix)
        hasher.combine(namespaceURI)

        for a in attributes {
            hasher.combine(a.0.localName)
            hasher.combine(a.0.prefix)
            hasher.combine(a.1.string)
        }
    }

    public static func == (lhs: ElementInfo, rhs: ElementInfo) -> Bool {
        guard lhs.tagName == rhs.tagName else { return false }
        guard lhs.namespaceURI == rhs.namespaceURI else { return false }
        guard lhs.attributes.count == rhs.attributes.count else { return false }

        for lhsa in lhs.attributes {
            if !attributeList(rhs.attributes, has: lhsa) { return false }
        }

        return true
    }

    public var saxAttributes: [SAXAttribute] {
        var a2: [SAXAttribute] = []
        for o in attributes {
            a2.append(SAXAttribute(localName: o.0.localName, prefix: o.0.prefix, namespaceURI: namespaceURI, content: o.1.string, isDefault: false))
        }
        return a2
    }

    public var namespaces: [String: String] {
        var ns: [String: String] = [:]
        for o in attributes {
            if o.0.prefix == "xmlns" {
                ns[o.0.localName] = o.1.string
            }
        }
        return ns
    }

    public var defaultNamespace: String? {
        for o in attributes {
            if o.0.prefix == nil && o.0.localName == "xmlns" {
                return o.1.string
            }
        }
        return nil
    }
}

@inlinable func attributeList(_ arr: [NSAttribute], has attribute: NSAttribute) -> Bool {
    for a in arr {
        if a == attribute { return true }
    }
    return false
}
