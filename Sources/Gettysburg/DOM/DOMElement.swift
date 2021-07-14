/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DOMElement.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 11, 2021
 *
  * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided
 * that the above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*****************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public class DOMElement: DOMParentNode {
    struct NSName: Hashable {
        let localName: String
        let uri:       String
    }

    //@f:0
    public override     var nodeType:     NodeType               { .Element }
    public              var tagName:      String                 { nodeName }
    public private(set) var attributes:   [DOMAttribute]         = []
    private             var _attrsCache1: [String: DOMAttribute] = [:]
    private             var _attrsCache2: [NSName: DOMAttribute] = [:]
    //@f:1

    init(owningDocument: DOMDocument, tagName: String, uri: String?) { super.init(owningDocument: owningDocument, qName: tagName, uri: uri) }

    public func forEachElement(deep: Bool = true, _ body: (DOMElement) throws -> Void) rethrows {
        try forEachNode(ofType: .Element) {
            if let e = ($0 as? DOMElement) {
                try body(e)
                if deep { try forEachElement(deep: deep, body) }
            }
        }
    }

    public func elements(deep: Bool = true, where body: (DOMElement) throws -> Bool) rethrows -> [DOMElement] {
        var out: [DOMElement] = []
        try forEachElement(deep: deep) { if try body($0) { out <+ $0 } }
        return out
    }

    public func elementsWith(tagName: String, deep: Bool = true) -> [DOMElement] { elements(deep: deep) { $0.tagName == tagName } }

    public func elementsWith(localName: String, uri: String, deep: Bool = true) -> [DOMElement] { elements(deep: deep) { $0.localName == localName && $0.uri == uri } }

    public func attributeValueWith(name: String) -> String? { attributeWith(name: name)?.value }

    public func attributeValueWith(localName: String, uri: String) -> String? { attributeWith(localName: localName, uri: uri)?.value }

    public func attributeWith(name: String) -> DOMAttribute? {
        if let a = _attrsCache1[name] { return a }
        guard let a = attributes.first(where: { $0.nodeName == name }) else { return nil }
        _attrsCache1[name] = a
        return a
    }

    public func attributeWith(localName: String, uri: String) -> DOMAttribute? {
        let key = NSName(localName: localName, uri: uri)
        if let a = _attrsCache2[key] { return a }
        guard let a = attributes.first(where: { $0.localName == localName && $0.uri == uri }) else { return nil }
        _attrsCache2[key] = a
        return a
    }

    @discardableResult public func removeAttributeWith(name: String) -> DOMAttribute? {
        guard let idx = attributes.firstIndex(where: { $0.nodeName == name }) else { return nil }
        return removeAttribute(at: idx)
    }

    @discardableResult public func removeAttributeWith(localName: String, uri: String) -> DOMAttribute? {
        guard let idx = attributes.firstIndex(where: { $0.localName == localName && $0.uri == uri }) else { return nil }
        return removeAttribute(at: idx)
    }

    @discardableResult public func removeAttribute(_ attr: DOMAttribute) throws -> DOMAttribute {
        guard let idx = attributes.firstIndex(where: { $0 === attr }) else { throw DOMError.Hierarchy(description: "Attribute does not belong to this element.") }
        return removeAttribute(at: idx)
    }

    @discardableResult public func addAttribute(name: String, value: String, isDefault: Bool = false) -> DOMAttribute? {
        let old     = removeAttributeWith(name: name)
        let newAttr = DOMAttribute(owningDocument: owningDocument!, qName: name, value: value, isDefault: isDefault)
        attributes <+ newAttr
        newAttr.owningElement = self
        return old
    }

    /// Add a new attribute.
    ///
    /// - Parameters:
    ///   - qName:
    ///   - uri:
    ///   - value:
    ///   - isDefault:
    /// - Returns: The replaced node.
    ///
    @discardableResult public func addAttribute(qName: String, uri: String, value: String, isDefault: Bool = false) -> DOMAttribute? {
        let old1    = removeAttributeWith(name: qName)
        let old2    = removeAttributeWith(localName: qName.splitPrefix().localName, uri: uri)
        let newAttr = DOMAttribute(owningDocument: owningDocument!, qName: qName, uri: uri, value: value, isDefault: isDefault)

        newAttr.owningElement = self
        attributes <+ newAttr
        return old2 ?? old1
    }

    @discardableResult public func addAttribute(_ attr: DOMAttribute) throws -> DOMAttribute? {
        guard attr.owningDocument === owningDocument else { throw DOMError.WrongDocument() }
        guard attr.owningElement !== self else { return nil }

        if let oe = attr.owningElement { try oe.removeAttribute(attr) }
        if let uri = attr.uri { return addAttribute(qName: attr.nodeName, uri: uri, value: attr.value, isDefault: attr.isDefault) }
        return addAttribute(name: attr.nodeName, value: attr.value, isDefault: attr.isDefault)
    }

    private func removeWithSameName(attr: DOMAttribute) -> DOMAttribute? {
        let oldAttr = removeAttributeWith(name: attr.nodeName)
        if let uri = attr.uri, let other = removeAttributeWith(localName: attr.localName, uri: uri) { return other }
        return oldAttr
    }

    private func removeAttribute(at idx: Int) -> DOMAttribute {
        let a = attributes[idx]
        while let x = _attrsCache1.first(where: { _, v in v == a }) { _attrsCache1.removeValue(forKey: x.key) }
        while let x = _attrsCache2.first(where: { _, v in v == a }) { _attrsCache2.removeValue(forKey: x.key) }
        attributes.remove(at: idx)
        a.owningElement = nil
        return a
    }
}
