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
    guard let ch = str.skipWS(&idx, position: &pos, peek: false) else { throw emptyContentListError(position: pos) }
    guard ch == listOpenChar else { throw unexpectedCharError(position: pos, found: ch, expected: listOpenChar) }

    var content:  [(DocPosition, ElementDeclNode.ContentBase)] = []
    var listType: ElementDeclNode.ContentList.ListType?        = nil
    var reqType:  ElementDeclNode.ContentBase.Requirement      = .Required

    repeat {
        guard let ch = str.skipWS(&idx, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }

        switch ch {
            case ")":
                let cc = content.count
                guard cc > 0 else { throw emptyContentListError(position: pos) }
                if cc == 1 { listType = .Sequence }
                reqType = getRequirement(content: str, index: &idx, position: &pos)

                if type(of: content[0].1) == ElementDeclNode.PCData.self {
                    try validatePCDataList(isRoot: isRoot, content: str, index: &idx, position: &pos, list: content, listType: &listType, reqType: &reqType)
                }

                if cc > 1 {
                    for i in (1 ..< (content.endIndex - 1)) {
                        guard type(of: content[i].1) != ElementDeclNode.PCData.self else { throw unexpectedPCDataError(position: pos) }
                    }
                }

                return ElementDeclNode.ContentList(reqType, listType!, content.map({ $0.1 }))
            default: break
        }
    }
    while true
}

private func validatePCDataList<S>(isRoot: Bool, content str: S, index idx: inout String.Index, position pos: inout DocPosition, list: [(DocPosition, ElementDeclNode.ContentBase)], listType: inout ElementDeclNode.ContentList.ListType?, reqType: inout ElementDeclNode.ContentBase.Requirement) throws where S: StringProtocol {
    let cc             = list.count
    let zom: Character = ElementDeclNode.ContentBase.Requirement.ZeroOrMore.rawValue[0]
    guard isRoot else { throw unexpectedPCDataError(position: list[0].0) }

    if cc == 1 {
        if try nextChar(content: str, index: &idx, position: &pos, peek: true) == zom { advanceIndex(content: str, index: &idx, position: &pos) }
        listType = .Choice
    }
    else {
        let ch = try nextChar(content: str, index: &idx, position: &pos)
        guard ch == zom else { throw unexpectedCharError(position: pos, found: ch, expected: zom) }
        guard listType == .Choice else { throw SAXError.MalformedElementDecl(position: pos, description: "Content list separator must be '|' not ','.") }
    }

    reqType = .ZeroOrMore
}

private func getRequirement<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition) -> ElementDeclNode.ContentBase.Requirement where S: StringProtocol {
    if idx < str.endIndex, let r = ElementDeclNode.ContentBase.Requirement(rawValue: String(str[idx])) {
        advanceIndex(content: str, index: &idx, position: &pos)
        return r
    }
    return ElementDeclNode.ContentBase.Requirement.Required
}

private func unexpectedPCDataError(position pos: DocPosition) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: "\"\(pcdata)\" not expected here.")
}

private func emptyContentListError(position pos: DocPosition) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: "Empty Content List")
}

private func unexpectedCharError(position pos: DocPosition, found ch: Character, expected exp: Character...) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Unexpected character", found: ch, expected: exp))
}

private func nextChar<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition, peek: Bool = false) throws -> Character where S: StringProtocol {
    guard idx < str.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }
    let ch: Character = str[idx]
    if !peek { advanceIndex(content: str, index: &idx, position: &pos) }
    return ch
}

private func advanceIndex<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition) where S: StringProtocol {
    pos.update(str[idx])
    str.formIndex(after: &idx)
}



































