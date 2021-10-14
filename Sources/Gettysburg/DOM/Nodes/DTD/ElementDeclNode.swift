/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: ElementDeclNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 10/14/21
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

open class ElementDeclNode: Node {

    public class ContentBase {
        public enum Requirement: String { case Required = "", Optional = "?", OneOrMore = "+", ZeroOrMore = "*" }

        public var requirement: Requirement

        init(_ requirement: Requirement) {
            self.requirement = requirement
        }
    }

    public class ContentList: ContentBase {
        public enum ListType: String { case Sequence = ",", Choice = "|" }

        public var content:  [ContentBase]
        public var type:     ListType
        public var isPCData: Bool { content.count == 1 && Swift.type(of: content[0]) == PCData.self }
        public var isMixed:  Bool { content.count > 1 && Swift.type(of: content[0]) == PCData.self }

        init(_ requirement: Requirement, _ type: ListType, _ content: [ContentBase]) {
            self.type = type
            self.content = content
            super.init(requirement)
        }
    }

    public class ContentItem: ContentBase {
        public var name: QName

        init(_ requirement: Requirement, _ name: String) {
            self.name = QName(qName: name)
            super.init(requirement)
        }
    }

    public class PCData: ContentBase {
        init() { super.init(.ZeroOrMore) }
    }
}

public func parseContentList<S>(content str: S, position: DocPosition) throws -> ElementDeclNode.ContentList where S: StringProtocol {
    var pos: DocPosition  = position
    var idx: String.Index = str.startIndex

    return try parseContentList(content: str, index: &idx, position: &pos, isRoot: true)
}

private let listOpenChar:  Character = "("
private let listCloseChar: Character = ")"
private let pcdata:        String    = "#PCDATA"
private let mixedMarker:   String    = "\(listOpenChar)\(pcdata)"
private let pcdataMarker:  String    = "\(mixedMarker)\(listCloseChar)"

private func parseContentList<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition, isRoot: Bool = false) throws -> ElementDeclNode.ContentList where S: StringProtocol {
    guard let ch = str.skipWS(&idx, position: &pos, peek: true) else { throw SAXError.MalformedElementDecl(position: pos, description: "Empty Content List") }
    guard ch == listOpenChar else { throw SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Invalid Character", found: ch, expected: listOpenChar)) }
    let _idx = idx

    if isRoot && testPrefix(marker: pcdataMarker, content: str, index: &idx) {
        pos.update(str[_idx ..< idx])
        if let ch = str.skipWS(&idx, position: &pos, peek: true) { throw SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Invalid Character", found: ch)) }
        return ElementDeclNode.ContentList(.Required, .Choice, [ ElementDeclNode.PCData() ])
    }

    var listType: ElementDeclNode.ContentList.ListType? = nil
    var list: [ElementDeclNode.ContentBase] = []

    if isRoot && testPrefix(marker: mixedMarker, content: str, index: &idx) {
        guard let ch = str.skipWS(&idx, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: "Content List Not Closed") }
        guard ch == "|" else { throw SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Invalid Character", found: ch, expected: "|")) }
        listType = .Choice
        list <+ ElementDeclNode.PCData()
    }
    else {
        str.formIndex(after: &idx)
    }

    repeat {
        guard let ch = str.skipWS(&idx, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: "Content List Not Closed") }
        guard ch != listCloseChar else { break }
        if ch == listOpenChar {
            list <+ try parseContentList(content: str, index: &idx, position: &pos, isRoot: false)
        }
    }
    while true
    fatalError("DONE")
}

private func testPrefix<S>(marker: String, content str: S, index idx: inout String.Index) -> Bool where S: StringProtocol {
    var idx1 = idx
    var idx2 = marker.startIndex

    while idx1 < str.endIndex {
        guard str[idx1] == marker[idx2] else { break }
        str.formIndex(after: &idx1)
        marker.formIndex(after: &idx2)
        guard idx2 < marker.endIndex else {
            idx = idx1
            return true
        }
    }

    return false
}
