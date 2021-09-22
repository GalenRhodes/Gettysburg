/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: ElementDeclNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/13/21
 *
 * Copyright © 2021. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *===============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

let OrderedChar:   Character = ","
let UnorderedChar: Character = "|"
let StartListChar: Character = "("
let EndListChar:   Character = ")"

open class ElementDeclNode: DTDElement {
    //@f:0
    public override var nodeType:    NodeTypes { .ElementDecl }
    public          var contentType: ContentType
    public          var content:     ContentList?
    //@f:1

    init(ownerDocument: DocumentNode, qName: String, namespaceURI: String, contentType: ContentType, content: String, position pos: inout DocPosition) throws {
        self.contentType = contentType
        self.content = try ContentList(content: content, position: &pos, allowPCData: (contentType == .Mixed))
        super.init(ownerDocument: ownerDocument, qName: qName, namespaceURI: namespaceURI)
    }

    init(ownerDocument: DocumentNode, name: String, contentType: ContentType, content: String, position pos: inout DocPosition) throws {
        self.contentType = contentType
        self.content = try ContentList(content: content, position: &pos, allowPCData: (contentType == .Mixed))
        super.init(ownerDocument: ownerDocument, name: name)
    }

    init(ownerDocument: DocumentNode, qName: String, namespaceURI: String, contentType: ContentType, content: ContentList? = nil) {
        self.contentType = contentType
        self.content = content
        super.init(ownerDocument: ownerDocument, qName: qName, namespaceURI: namespaceURI)
    }

    init(ownerDocument: DocumentNode, name: String, contentType: ContentType, content: ContentList? = nil) {
        self.contentType = contentType
        self.content = content
        super.init(ownerDocument: ownerDocument, name: name)
    }

    public enum ContentType: String, Codable {
        case Empty = "EMPTY"
        case `Any` = "ANY"
        case Elements
        case Mixed
    }
}

extension ElementDeclNode {

    public class ContentItem {
        public let type:         ItemType
        public let multiplicity: Multiplicity

        public init(type: ItemType, multiplicity: Multiplicity) {
            self.type = type
            self.multiplicity = multiplicity
        }

        public enum ItemType: String, Codable { case List, Element, PCData = "#PCDATA" }

        public enum Multiplicity: String, Codable { case Optional = "?", Once = "", OneOrMore = "+", ZeroOrMore = "*" }
    }

    /*===========================================================================================================================*/
    /// Allowed content item list.
    ///
    public class ContentList: ContentItem {
        public enum ListType: String, Codable { case Ordered = ",", Unordered = "|" }

        public var listType: ListType
        public var content:  [ContentItem] = []

        init(multiplicity: Multiplicity, listType: ListType) {
            self.listType = listType
            super.init(type: .List, multiplicity: multiplicity)
        }

        convenience init(content c: String, position pos: inout DocPosition, allowPCData: Bool) throws {
            var i = c.startIndex
            try self.init(content: c, index: &i, position: &pos, allowPCData: allowPCData)
        }

        init(content c: String, index i: inout String.Index, position pos: inout DocPosition, allowPCData: Bool) throws {
            guard let ch = c.skipWS(&i, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }
            guard ch == StartListChar else { throw SAXError.MalformedElementDecl(position: pos, description: "\(MsgContentListBadPrefix) \(quote(StartListChar)).") }
            guard let ch = c.skipWS(&i, position: &pos, peek: true) else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }

            var lt: ListType? = nil

            if ch == "#" {
                guard allowPCData else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: ch)) }
                content <+ try PCData(content: c, index: &i, position: &pos)
                guard let ch = c.skipWS(&i, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }

                if ch == EndListChar {
                    listType = .Unordered
                    super.init(type: .List, multiplicity: .Once)
                    return
                }
                else if ch != UnorderedChar {
                    throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: ch, expected: EndListChar, UnorderedChar))
                }

                lt = .Unordered
            }

            repeat {
                guard let c1 = c.skipWS(&i, position: &pos, peek: true) else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }

                if c1.isXmlNameStartChar {
                    content <+ try Element(content: c, index: &i, position: &pos)
                }
                else if c1 == StartListChar {
                    content <+ try ContentList(content: c, index: &i, position: &pos, allowPCData: false)
                }
                else {
                    throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c1))
                }

                guard let c2 = c.skipWS(&i, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }

                if value(c2, isOneOf: OrderedChar, UnorderedChar) {
                    let sc2 = String(c2)

                    if let _lt = lt?.rawValue {
                        guard _lt == sc2 else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: sc2, expected: _lt)) }
                    }
                    else {
                        lt = ListType(rawValue: sc2)!
                    }
                }
                else {
                    guard c2 == EndListChar else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c2)) }
                    break
                }
            }
            while true

            guard content.isNotEmpty else { throw SAXError.MalformedElementDecl(position: pos, description: MsgEmptyContentList) }
            self.listType = ((lt == nil) ? .Ordered : lt!)
            super.init(type: .List, multiplicity: Multiplicity.get(c, index: &i, position: &pos))
        }
    }

    /*===========================================================================================================================*/
    /// PCData allowed content item.
    ///
    public class PCData: ContentItem {
        init() { super.init(type: .PCData, multiplicity: .Once) }

        init(content c: String, index i: inout String.Index, position pos: inout DocPosition) throws {
            guard let _ = c.skipWS(&i, position: &pos) else { throw SAXError.UnexpectedEndOfInput(position: pos) }

            for xch in ItemType.PCData.rawValue {
                guard xch == c[i] else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c[i], expected: xch)) }
                pos.update(xch)
                c.formIndex(after: &i)
                guard i < c.endIndex else { throw SAXError.UnexpectedEndOfInput(position: pos) }
            }
            guard !Multiplicity.test(c[i]) else {
                let msg = unexpectedMessage(found: c[i], expected: UnorderedChar, EndListChar)
                throw SAXError.MalformedElementDecl(position: pos, description: msg)
            }
            super.init(type: .PCData, multiplicity: .Once)
        }
    }

    /*===========================================================================================================================*/
    /// Element allowed content item.
    ///
    public class Element: ContentItem {
        public let name: QName

        init(name: String, multiplicity: Multiplicity) {
            self.name = QName(qName: name)
            super.init(type: .Element, multiplicity: multiplicity)
        }

        init(content c: String, index i: inout String.Index, position pos: inout DocPosition) throws {
            guard let ch = c.skipWS(&i, position: &pos, peek: true) else { throw SAXError.UnexpectedEndOfInput(position: pos) }
            guard ch.isXmlNameStartChar else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: ch)) }

            var data: [Character] = []
            while i < c.endIndex && c[i].isXmlNameChar {
                data <+ c[i]
                pos.update(c[i])
                c.formIndex(after: &i)
            }
            self.name = QName(qName: String(data))
            super.init(type: .Element, multiplicity: Multiplicity.get(c, index: &i, position: &pos))
        }
    }
}

extension ElementDeclNode.ContentItem.Multiplicity {
    @inlinable static func test(_ ch: Character) -> Bool { value(ch, isOneOf: "?", "+", "*") }

    @inlinable static func get(_ s: String, index i: inout String.Index, position pos: inout DocPosition) -> Self {
        guard i < s.endIndex else { return .Once }
        let ch: Character = s[i]
        guard test(ch), let r = ElementDeclNode.ContentItem.Multiplicity(rawValue: String(ch)) else { return .Once }
        pos.update(ch)
        s.formIndex(after: &i)
        return r
    }
}
