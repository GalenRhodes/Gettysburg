/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: InternalTools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 10/16/21
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

@inlinable func unexpectedMessage(found f: Character, expected e: Character...) -> String { unexpectedMessage(found: String(f), expected: e.map { String($0) }) }

@inlinable func unexpectedMessage(found f: Character, expected e: [Character]) -> String { unexpectedMessage(found: String(f), expected: e.map { String($0) }) }

@inlinable func unexpectedMessage<S>(found f: S, expected e: S...) -> String where S: StringProtocol { unexpectedMessage(found: f, expected: e) }

@inlinable func unexpectedMessage<S>(found f: S, expected e: [S]) -> String where S: StringProtocol {
    e.isNotEmpty ? "\(quote(f)) not expected here." : listedMessage(prefix: "Expected", postfix: "but found \(quote(f)) instead.", e)
}

@inlinable func listedMessage(prefix: String? = nil, postfix: String? = nil, conjunction: String = "or", _ list: Character...) -> String {
    listedMessage(prefix: prefix, postfix: postfix, conjunction: conjunction, list.map { String($0) })
}

@inlinable func listedMessage(prefix: String? = nil, postfix: String? = nil, conjunction: String = "or", _ list: [Character]) -> String {
    listedMessage(prefix: prefix, postfix: postfix, conjunction: conjunction, list.map { String($0) })
}

@inlinable func listedMessage<S>(prefix: String? = nil, postfix: String? = nil, conjunction: String = "or", _ list: S...) -> String where S: StringProtocol {
    listedMessage(prefix: prefix, postfix: postfix, conjunction: conjunction, list)
}

@inlinable func listedMessage<S>(prefix: String? = nil, postfix: String? = nil, conjunction: String = "or", _ list: [S]) -> String where S: StringProtocol {
    var str: String = ""
    if let s = prefix { str += "\(s) " }
    str += msgList(conjunction: conjunction, list)
    if let s = postfix { str += " \(s)" }
    return str
}

@inlinable func msgList(conjunction: String = "or", _ list: Character...) -> String { msgList(conjunction: conjunction, list.map { String($0) }) }

@inlinable func msgList(conjunction: String = "or", _ list: [Character]) -> String { msgList(conjunction: conjunction, list.map { String($0) }) }

@inlinable func msgList<S>(conjunction: String = "or", _ list: S...) -> String where S: StringProtocol { msgList(conjunction: conjunction, list) }

@inlinable func msgList<S>(conjunction: String = "or", _ list: [S]) -> String where S: StringProtocol {
    switch list.count {
        case 0: return ""
        case 1: return quote(list[0])
        case 2: return "\(quote(list[0])) \(conjunction) \(quote(list[1]))"
        default:
            var str: String = ""
            for i in (list.startIndex ..< (list.endIndex - 1)) { str += "\(quote(list[i])), " }
            return str + "\(conjunction) \(quote(list[list.endIndex - 1]))"
    }
}

@inlinable func quote<S>(_ str: S) -> String where S: StringProtocol { "`\(str)`" }

@inlinable func quote(_ c: Character) -> String { quote(String(c)) }

