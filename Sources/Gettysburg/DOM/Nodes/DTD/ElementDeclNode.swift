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

    public init(ownerDocument: DocumentNode?, qName: String, namespaceURI: String?, contentType: ContentType, content: String, position pos: inout DocPosition) throws {
        self.contentType = contentType
        self.content = try ContentList(content: content, position: &pos, allowPCData: (contentType == .Mixed))
        super.init(ownerDocument: ownerDocument, qName: qName, namespaceURI: namespaceURI)
    }

    init(ownerDocument: DocumentNode?, qName: String, namespaceURI: String?, contentType: ContentType, content: ContentList? = nil) {
        self.contentType = contentType
        self.content = content
        super.init(ownerDocument: ownerDocument, qName: qName, namespaceURI: namespaceURI)
    }

    public enum ContentType: String, Codable {
        case Empty = "EMPTY"
        case `Any` = "ANY"
        case Elements
        case Mixed
    }

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
            guard i < c.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }
            guard c[i] == StartListChar else { throw SAXError.MalformedElementDecl(position: pos, description: "\(MsgContentListBadPrefix) \(quote(StartListChar)).") }

            pos.update(StartListChar)
            c.formIndex(after: &i)
            var lt: ListType? = nil

            if c[i] == "#" {
                guard allowPCData else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c[i])) }
                content <+ try PCData(content: c, index: &i, position: &pos)
                lt = .Unordered
                listType = .Unordered

                if c[i] == EndListChar {
                    super.init(type: .List, multiplicity: .Once)
                    return
                }
                else if c[i] != UnorderedChar {
                    throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c[i], expected: EndListChar, UnorderedChar))
                }
            }

            repeat {
                let c0 = c[i]
                if c0.isXmlNameStartChar {
                    content <+ try Element(content: c, index: &i, position: &pos)
                }
                else if c0 == StartListChar {
                    content <+ try ContentList(content: c, index: &i, position: &pos, allowPCData: false)
                }
                else {
                    throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c0))
                }

                let c1 = c[i]
                pos.update(c1)
                if value(c1, isOneOf: OrderedChar, UnorderedChar) {
                    let x1 = String(c1)
                    if let _lt = lt?.rawValue {
                        guard _lt == x1 else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: x1, expected: _lt)) }
                    }
                    else {
                        lt = ListType(rawValue: x1)!
                    }
                }
                else {
                    guard c1 == EndListChar else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c1)) }
                    c.formIndex(after: &i)
                    break
                }
            }
            while true

            guard content.isNotEmpty else { throw SAXError.MalformedElementDecl(position: pos, description: MsgEmptyContentList) }
            self.listType = ((lt == nil) ? .Ordered : lt!)

            if i < c.endIndex && value(c[i], isOneOf: "?", "+", "*") {
                super.init(type: .List, multiplicity: Multiplicity(rawValue: String(c[i]))!)
                c.formIndex(after: &i)
            }
            else {
                super.init(type: .List, multiplicity: .Once)
            }
        }
    }

    public class PCData: ContentItem {
        init() { super.init(type: .PCData, multiplicity: .Once) }

        init(content c: String, index i: inout String.Index, position pos: inout DocPosition) throws {
            guard let j = c.index(i, offsetBy: 7, limitedBy: c.endIndex) else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }

            let ss = c[i ..< j]

            guard String(ss) == ItemType.PCData.rawValue else { throw SAXError.MalformedElementDecl(position: pos, description: "\(MsgUnrecognizedTag): \(quote(ss))") }
            guard j < c.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: MsgUnexpectedEOF) }

            pos.update(ss)
            let ch = c[j]

            guard value(ch, isOneOf: UnorderedChar, EndListChar) else {
                let msg = ((ch == OrderedChar) ? unexpectedMessage(found: ch, expected: EndListChar, UnorderedChar) : unexpectedMessage(found: ch))
                throw SAXError.MalformedElementDecl(position: pos, description: msg)
            }

            i = j
            pos.update(ch)
            super.init(type: .PCData, multiplicity: .Once)
        }
    }

    public class Element: ContentItem {
        public let name: QName

        init(name: String, multiplicity: Multiplicity) {
            self.name = QName(qName: name)
            super.init(type: .Element, multiplicity: multiplicity)
        }

        init(content c: String, index i: inout String.Index, position pos: inout DocPosition) throws {
            guard i < c.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: MsgEmptyElementName) }
            guard c[i].isXmlNameStartChar else { throw SAXError.MalformedElementDecl(position: pos, description: unexpectedMessage(found: c[i])) }

            var chars: [Character] = []
            repeat {
                chars <+ c[i]
                pos.update(c[i])
                c.formIndex(after: &i)
            }
            while i < c.endIndex && c[i].isXmlNameChar
            self.name = QName(qName: String(chars))

            if i < c.endIndex && value(c[i], isOneOf: "?", "+", "*") {
                super.init(type: .Element, multiplicity: Multiplicity(rawValue: String(c[i]))!)
                c.formIndex(after: &i)
            }
            else {
                super.init(type: .Element, multiplicity: .Once)
            }
        }
    }
}

extension ElementDeclNode.ContentItem.Multiplicity {
    @inlinable static func get()
}
