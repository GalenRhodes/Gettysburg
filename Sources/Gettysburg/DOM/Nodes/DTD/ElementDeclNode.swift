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

    public class ContentBase: CustomStringConvertible {
        public enum Requirement: String { case Required = "", Optional = "?", OneOrMore = "+", ZeroOrMore = "*" }

        public var description: String { "" }
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
        public override var description: String {
            var str: String = "("
            str += content.componentsJoined(by: type.rawValue)
            str += ")"
            str += (isPCData ? "" : (isMixed ? Requirement.ZeroOrMore.rawValue : requirement.rawValue))
            return str
        }

        init(_ requirement: Requirement, _ type: ListType, _ content: [ContentBase]) {
            self.type = type
            self.content = content
            super.init(requirement)
        }
    }

    public class ContentItem: ContentBase {
        public var name: QName
        public override var description: String { "\(name)\(requirement.rawValue)" }

        init(_ requirement: Requirement, _ name: String) {
            self.name = QName(qName: name)
            super.init(requirement)
        }
    }

    public class PCData: ContentBase {
        public override var description: String { pcdata }

        init() { super.init(.ZeroOrMore) }
    }
}

/*===============================================================================================================================*/
/// Parse the content list.
///
/// - Parameters:
///   - str: The string to parse.
///   - position: The position in the document.
/// - Returns: An instance of `ElementDeclNode.ContentList`.
/// - Throws: If the content list is malformed.
///
public func parseContentList<S>(content str: S, position: DocPosition) throws -> ElementDeclNode.ContentList where S: StringProtocol {
    var pos: DocPosition  = position
    var idx: String.Index = str.startIndex

    return try parseContentList(content: str, index: &idx, position: &pos, isRoot: true)
}

private typealias _List = ElementDeclNode.ContentList
private typealias _Base = ElementDeclNode.ContentBase
private typealias _TList = (DocPosition, _Base)
private typealias _Req = _Base.Requirement
private typealias _LType = _List.ListType

private let listOpenChar:  Character = "("
private let listCloseChar: Character = ")"
private let pcdata:        String    = "#PCDATA"
private let mixedMarker:   String    = "\(listOpenChar)\(pcdata)"
private let pcdataMarker:  String    = "\(mixedMarker)\(listCloseChar)"

/*===============================================================================================================================*/
private func parseContentList<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition, isRoot: Bool) throws -> _List where S: StringProtocol {
    guard let ch = str.skipWS(&idx, position: &pos, peek: false) else { throw emptyContentListError(position: pos) }
    guard ch == listOpenChar else { throw unexpectedCharError(position: pos, found: ch, expected: listOpenChar) }

    var content:   [_TList] = []
    var listType:  _LType?  = nil
    var inBetween: Bool     = false

    while idx < str.endIndex {
        let ch: Character = str[idx]

        switch inBetween {
            case true:
                switch ch {
                    case ")":      return try finishContentList(content: str, index: &idx, position: &pos, contentList: content, listType: listType, isRoot: isRoot)
                    case "|", ",": try handleListType(str, &idx, &pos, ch, &listType, &inBetween)
                    default:       try handleInBetweenWS(ch, str, &idx, &pos)
                }
            case false:
                switch ch {
                    case ")": return try finishContentList(content: str, index: &idx, position: &pos, contentList: content, listType: listType, isRoot: isRoot)
                    case "(": try handleSubList(str, &idx, &pos, &content, &inBetween)
                    case "#": try handlePCData(str, &idx, &pos, &content, isRoot, &inBetween)
                    default:  try handleCharacter(ch, str, &idx, &pos, &content, &inBetween)
                }
        }
    }

    throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.")
}

/*===============================================================================================================================*/
private func handleInBetweenWS<S>(_ ch: Character, _ str: S, _ idx: inout String.Index, _ pos: inout DocPosition) throws where S: StringProtocol {
    guard ch.isXmlWhitespace else { throw unexpectedCharError(position: pos, found: ch) }
    guard let _ = str.skipWS(&idx, position: &pos, peek: true) else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }
}

/*===============================================================================================================================*/
private func handleSubList<S>(_ str: S, _ idx: inout String.Index, _ pos: inout DocPosition, _ content: inout [_TList], _ inBetween: inout Bool) throws where S: StringProtocol {
    let p = pos
    content <+ (p, try parseContentList(content: str, index: &idx, position: &pos, isRoot: false))
    inBetween = true
}

/*===============================================================================================================================*/
private func handleCharacter<S>(_ ch: Character, _ str: S, _ idx: inout String.Index, _ pos: inout DocPosition, _ content: inout [_TList], _ inBetween: inout Bool) throws where S: StringProtocol {
    if ch.isXmlWhitespace {
        guard let _ = str.skipWS(&idx, position: &pos, peek: true) else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }
    }
    else if ch.isXmlNameStartChar {
        try handleItemName(ch, str, &idx, &pos, &content)
        inBetween = true
    }
}

/*===============================================================================================================================*/
private func handlePCData<S>(_ str: S, _ idx: inout String.Index, _ pos: inout DocPosition, _ content: inout [_TList], _ isRoot: Bool, _ inBetween: inout Bool) throws where S: StringProtocol {
    let p = pos
    var x = pcdata.startIndex

    repeat {
        let c = str[idx]
        guard c == pcdata[x] else { throw SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Unexpected character", found: c, expected: pcdata[x])) }
        str.advanceIndex(index: &idx, position: &pos)
        guard idx < str.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }
        pcdata.formIndex(after: &x)
    }
    while x < pcdata.endIndex

    guard isRoot && content.isEmpty else { throw unexpectedPCDataError(position: p) }
    content <+ (p, ElementDeclNode.PCData())
    inBetween = true
}

/*===============================================================================================================================*/
private func handleItemName<S>(_ ch: Character, _ str: S, _ idx: inout String.Index, _ pos: inout DocPosition, _ content: inout [_TList]) throws where S: StringProtocol {
    let p                 = pos
    var c                 = ch
    var name: [Character] = []

    repeat {
        name <+ c
        str.advanceIndex(index: &idx, position: &pos)
        guard idx < str.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }
        c = str[idx]
    }
    while c.isXmlNameChar

    content <+ (p, ElementDeclNode.ContentItem(getRequirement(content: str, index: &idx, position: &pos), String(name)))
}

/*===============================================================================================================================*/
private func handleListType<S>(_ str: S, _ idx: inout String.Index, _ pos: inout DocPosition, _ ch: Character, _ listType: inout _LType?, _ inBetween: inout Bool) throws where S: StringProtocol {
    let ch1 = String(ch)
    str.advanceIndex(index: &idx, position: &pos)
    if let lt = listType { guard ch1 == lt.rawValue else { throw unexpectedCharError(position: pos, found: ch1, expected: lt.rawValue) } }
    else { listType = _LType(rawValue: ch1) }
    inBetween = false
}

/*===============================================================================================================================*/
/// Complete the list.
///
/// - Parameters:
///   - str: The string being parsed.
///   - idx: The index of the current character in the string.
///   - pos: The position (line, column) in the parent document.
///   - content: The current list of items.
///   - listType: The list type.
///   - isRoot: `true` if this is the root content list and not a nested list.
/// - Returns: A new instance of `ElementDeclNode.ContentList`.
/// - Throws: If the content list is malformed.
///
private func finishContentList<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition, contentList content: [_TList], listType: _LType?, isRoot: Bool) throws -> _List where S: StringProtocol {
    let cc = content.count
    guard cc > 0 else { throw emptyContentListError(position: pos) }
    str.advanceIndex(index: &idx, position: &pos)
    var listType = (cc == 1 ? .Sequence : listType)
    var reqType  = getRequirement(content: str, index: &idx, position: &pos)

    if type(of: content[0].1) == ElementDeclNode.PCData.self { try validatePCDataList(isRoot, str, &idx, &pos, content, &listType, &reqType) }
    if cc > 1 { try testNoMorePCData(content: content, position: pos) }

    return _List(reqType, listType!, content.map({ $0.1 }))
}

/*===============================================================================================================================*/
private func testNoMorePCData(content: [_TList], position pos: DocPosition) throws {
    for i in (1 ..< (content.endIndex - 1)) {
        guard type(of: content[i].1) != ElementDeclNode.PCData.self else {
            throw unexpectedPCDataError(position: pos)
        }
    }
}

/*===============================================================================================================================*/
/// Validate a content list that begins with #PCDATA.
///
/// - Parameters:
///   - str: The string being parsed.
///   - idx: The index of the current character in the string.
///   - pos: The position (line, column) in the parent document.
///   - content: The current list of items.
///   - listType: The list type.
///   - reqType: The requirement type.
///   - isRoot: `true` if this is the root content list and not a nested list.
/// - Throws: If the content list is malformed.
///
private func validatePCDataList<S>(_ isRoot: Bool, _ str: S, _ idx: inout String.Index, _ pos: inout DocPosition, _ content: [_TList], _ listType: inout _LType?, _ reqType: inout _Req) throws where S: StringProtocol {
    guard isRoot else { throw unexpectedPCDataError(position: content[0].0) }

    if content.count == 1 {
        reqType = .ZeroOrMore
        listType = .Choice
    }
    else {
        guard reqType == _Req.ZeroOrMore else { throw SAXError.MalformedElementDecl(position: pos, description: "") }
        guard listType == .Choice else { throw SAXError.MalformedElementDecl(position: pos, description: "Content list separator must be '|' not ','.") }
    }
}

/*===============================================================================================================================*/
/// Get the requirement for the content list item.
///
/// - Parameters:
///   - str: The string being parsed.
///   - idx: The index of the current character in the string.
///   - pos: The position (line, column) in the parent document.
/// - Returns: The requirement.
///
private func getRequirement<S>(content str: S, index idx: inout String.Index, position pos: inout DocPosition) -> _Req where S: StringProtocol {
    if idx < str.endIndex, let r = _Req(rawValue: String(str[idx])) {
        str.advanceIndex(index: &idx, position: &pos)
        return r
    }
    return _Req.Required
}

/*===============================================================================================================================*/
private func unexpectedPCDataError(position pos: DocPosition) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: "\"\(pcdata)\" not expected here.")
}

/*===============================================================================================================================*/
private func emptyContentListError(position pos: DocPosition) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: "Empty Content List")
}

/*===============================================================================================================================*/
private func unexpectedCharError(position pos: DocPosition, found ch: Character, expected exp: Character...) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Unexpected character", found: ch, expected: exp))
}

/*===============================================================================================================================*/
private func unexpectedCharError(position pos: DocPosition, found ch: String, expected exp: String...) -> SAXError.MalformedElementDecl {
    SAXError.MalformedElementDecl(position: pos, description: errorMessage(prefix: "Unexpected character", found: ch, expected: exp))
}
