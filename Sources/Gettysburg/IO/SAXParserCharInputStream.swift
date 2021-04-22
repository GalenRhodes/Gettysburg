/*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParserCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 3/28/21
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

/*===============================================================================================================================================================================*/
/// The final product...
///
public final class SAXParserCharInputStream: SAXCharInputStream {
    //@f:0
    public let parser:            SAXParser
    public var tabWidth:          Int8          { get { charStream.tabWidth } set { charStream.tabWidth = newValue }    }
    public var baseURL:           URL           { charStream.baseURL                                                    }
    public var url:               URL           { charStream.url                                                        }
    public var filename:          String        { charStream.filename                                                   }
    public var encodingName:      String        { charStream.encodingName                                               }
    public var markCount:         Int           { mStack.count                                                          }
    public var position:          TextPosition  { pos                                                                   }
    public var streamError:       Error?        { (isOpen ? error : nil)                                                }
    public var streamStatus:      Stream.Status { (isOpen ? (hasError ? .error : (hasChars ? .open : .atEnd)) : status) }
    public var isEOF:             Bool          { (streamStatus == .atEnd)                                              }
    public var hasCharsAvailable: Bool          { (isGood && hasChars)                                                  }

    private var charStream: MultiSAXSimpleCharInputStreamImpl
    private var pos:        TextPosition             = (0, 0)
    private var error:      Error?                   = nil
    private var status:     Stream.Status            = .notOpen
    private var mStack:     [MarkStackItem]          = []
    private var buffer:     [CharPos]                = []
    private var lock:       RecursiveLock            = RecursiveLock()

    private var isOpen:   Bool { (status == .open)                                   }
    private var isGood:   Bool { (isOpen && !hasError)                               }
    private var hasError: Bool { (error != nil)                                      }
    private var hasChars: Bool { (buffer.isNotEmpty || charStream.hasCharsAvailable) }
    //@f:1

    public init(_ inputStream: InputStream, url: URL, parser p: SAXParser) throws {
        let inputStream = ((inputStream as? MarkInputStream) ?? MarkInputStream(inputStream: inputStream))
        charStream = try MultiSAXSimpleCharInputStreamImpl(inputStream, url)
        parser = p
    }

    public func open() {
        lock.withLock {
            if status == .notOpen {
                charStream.open()
                error = charStream.streamError
                pos = charStream.position
                status = .open
            }
        }
    }

    public func close() {
        lock.withLock {
            if status == .open {
                status = .closed
                pos = (0, 0)
                error = nil
                charStream.close()
                buffer.removeAll()
                for mi in mStack { mi.data.removeAll() }
                mStack.removeAll()
            }
        }
    }

    public func read() throws -> Character? {
        try lock.withLock {
            guard isOpen else { return nil }
            if let er = error { throw er }
            if let cp = buffer.popFirst() { return pushChar(cp) }

            do {
                if let cp = try charStream.read() { return pushChar(cp) }
                return nil
            }
            catch let e {
                error = e
                throw e
            }
        }
    }

    public func append(to chars: inout [Character], maxLength: Int) throws -> Int {
        try lock.withLock {
            guard isOpen && maxLength != 0 else { return 0 }
            if let er = error { throw er }

            let ln = fixLength(maxLength)
            var cc = min(ln, buffer.count)

            if cc > 0 {
                pushChars(to: &chars, from: buffer[0 ..< cc])
                buffer.removeSubrange(0 ..< cc)
            }

            do {
                while cc < ln {
                    var cps: [CharPos] = []
                    let rcc: Int       = try charStream.append(to: &cps, maxLength: min(1024, (ln - cc)))
                    guard rcc > 0 else { break }
                    pushChars(to: &chars, from: cps)
                    cc += rcc
                }

                return cc
            }
            catch let e {
                error = e
                throw e
            }
        }
    }

    public func markSet() { lock.withLock { markSetP() } }

    public func markDelete() { lock.withLock { if isGood, let mi = mStack.popLast() { markErase(mi) } } }

    public func markReturn() { lock.withLock { if isGood, let mi = mStack.popLast() { markReturn(mi) } } }

    public func markReset() {
        lock.withLock {
            guard isGood else { return }
            if let mi = mStack.last { markReturn(mi) }
            else { markSetP() }
        }
    }

    public func markUpdate() {
        lock.withLock {
            guard isGood else { return }
            if let mi = mStack.last { mi.pos = pos; markErase(mi) }
            else { markSetP() }
        }
    }

    public func markBackup(count: Int) -> Int {
        lock.withLock {
            guard (isGood && (count > 0)), let mi = mStack.last else { return 0 }

            let cc = min(count, mi.data.count)
            let i2 = mi.data.endIndex
            let i1 = (i2 - cc)
            let rn = (i1 ..< i2)

            pos = mi.data[i1].pos
            buffer.insert(contentsOf: mi.data[rn], at: 0)
            mi.data.removeSubrange(rn)

            return cc
        }
    }

    public func stackNew(string: String, url: URL) throws {
        try lock.withLock { charStream.pushStream(try SAXSimpleStringCharInputStream(string, url)) }
    }

    public func stackNew(inputStream: InputStream, url: URL) throws {
        try lock.withLock { charStream.pushStream(try SAXSimpleIConvCharInputStream(inputStream: inputStream, url: url)) }
    }

    public func stackNew(data: Data, url: URL) throws {
        try lock.withLock { charStream.pushStream(try SAXSimpleStringCharInputStream(data, url, skipXMLDeclaration: true)) }
    }

    public func stackNew(url: URL) throws {
        try lock.withLock { charStream.pushStream(try SAXSimpleIConvCharInputStream(url: url)) }
    }

    public func stackNew(systemId: String) throws {
        try lock.withLock {
            guard let url = URL(string: systemId, relativeTo: baseURL) else { throw SAXError.MalformedURL(pos, url: systemId) }
            charStream.pushStream(try SAXSimpleIConvCharInputStream(url: url))
        }
    }

    private func markSetP() {
        mStack <+ MarkStackItem(pos: pos)
    }

    private func markErase(_ mi: MarkStackItem) {
        mi.data.removeAll()
    }

    private func markReturn(_ mi: MarkStackItem) {
        buffer.append(contentsOf: mi.data)
        pos = mi.pos
        markErase(mi)
    }

    private func pushChar(_ ch: CharPos) -> Character {
        if let mi = mStack.last { mi.data <+ ch }
        pos = ch.pos
        return ch.char
    }

    private func pushChars<T>(to chars: inout [Character], from cps: T) where T: RandomAccessCollection, T.Element == CharPos {
        guard cps.isNotEmpty else { return }
        chars.append(contentsOf: cps.map { $0.char })
        pos = cps.last!.pos
        if let mi = mStack.last { mi.data.append(contentsOf: cps) }
    }

    private class MarkStackItem {
        var data: [CharPos] = []
        var pos:  TextPosition

        init(pos: TextPosition) { self.pos = pos }
    }
}

