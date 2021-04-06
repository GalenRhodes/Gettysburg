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

public class SAXParserCharInputStream: SAXCharInputStream {
    @usableFromInline typealias StreamStackItem = (TextPosition, SAXChildCharInputStream)

    //@f:0
    public            let parser:            SAXParser
    public      final var isEOF:             Bool                    { lock.withLock { (streamStatus == .atEnd)                                              } }
    public      final var hasCharsAvailable: Bool                    { lock.withLock { hasChars                                                              } }
    public      final var streamError:       Error?                  { lock.withLock { ((status == .open) ? error : nil)                                     } }
    public      final var markCount:         Int                     { lock.withLock { mstk.count                                                            } }
    public      final var position:          TextPosition            { lock.withLock { pos                                                                   } }
    public      final var streamStatus:      Stream.Status           { lock.withLock { (isOpen ? (hasError ? .error : (hasChars ? .open : .atEnd)) : status) } }
    public      final var filename:          String                  { lock.withLock { charStream.filename                                                   } }
    public      final var encodingName:      String                  { lock.withLock { charStream.encodingName                                               } }
    public      final var baseURL:           URL                     { lock.withLock { charStream.baseURL                                                    } }
    public      final var url:               URL                     { lock.withLock { charStream.url                                                        } }
    public      final var tabWidth:          Int8                    { get { lock.withLock { tab } } set { lock.withLock { tab = newValue } }                  }

    @usableFromInline let lock:              RecursiveLock           = RecursiveLock()
    @usableFromInline var pos:               TextPosition            = (0, 0)
    @usableFromInline var status:            Stream.Status           = .notOpen
    @usableFromInline var error:             Error?                  = nil
    @usableFromInline var tab:               Int8                    = 4
    @usableFromInline var buffer:            [Character]             = []
    @usableFromInline var mstk:              [MarkItem]              = []
    @usableFromInline var sstk:              [StreamStackItem]       = []
    @usableFromInline var charStream:        SAXChildCharInputStream

    @inlinable  final var isOpen:            Bool                    { (status == .open)     }
    @inlinable  final var hasError:          Bool                    { (error != nil)        }
    @inlinable  final var isGood:            Bool                    { (isOpen && !hasError) }
    //@f:1

    public init(inputStream: InputStream, url: URL, parser: SAXParser) throws {
        charStream = try SAXIConvCharInputStream(inputStream: inputStream, url: url)
        self.parser = parser
    }

    deinit { _close() }

    public final func open() {
        lock.withLock {
            if status == .notOpen {
                charStream.open()
                pos = (1, 1)
                error = charStream.streamError
                status = .open
            }
        }
    }

    public final func close() {
        lock.withLock {
            _close()
        }
    }

    public final func read() throws -> Character? {
        try lock.withLock {
            guard isOpen else { return nil }
            if let e = error { throw e }

            do {
                if let ch = buffer.popFirst() { return pushChar(char: ch) }
                repeat { if let ch = try charStream.read() { return pushChar(char: ch) } }
                while popStream()
                return nil
            }
            catch let e { error = e; throw e }
        }
    }

    public final func read(chars: inout [Character], maxLength: Int) throws -> Int {
        try lock.withLock {
            if !chars.isEmpty { chars.removeAll(keepingCapacity: true) }
            return try _append(to: &chars, maxLength: maxLength)
        }
    }

    public final func append(to chars: inout [Character], maxLength: Int) throws -> Int {
        try lock.withLock {
            try _append(to: &chars, maxLength: maxLength)
        }
    }

    public final func markSet() {
        lock.withLock {
            _markSet()
        }
    }

    public final func markDelete() {
        lock.withLock {
            _markDelete()
        }
    }

    public final func markReturn() {
        lock.withLock {
            _markReturn()
        }
    }

    public final func markReset() {
        lock.withLock {
            _markReturn()
            _markSet()
        }
    }

    public final func markUpdate() {
        lock.withLock {
            _markDelete()
            _markSet()
        }
    }

    @discardableResult public final func markBackup(count: Int) -> Int {
        lock.withLock {
            guard isGood else { return 0 }
            guard let mi = mstk.last else { return 0 }
            let cc = min(count, mi.data.count)
            guard cc > 0 else { return 0 }
            let idx   = (mi.data.endIndex - cc)
            let range = (idx ..< mi.data.endIndex)
            pos = mi.data[idx].0
            buffer.insert(contentsOf: mi.data[range].map({ $0.1 }), at: 0)
            buffer.removeSubrange(range)
            return cc
        }
    }

    public final func stackNew(inputStream: InputStream, url: URL) throws {
        try lock.withLock {
            do { pushStream(try SAXIConvCharInputStream(inputStream: inputStream, url: url)) }
            catch let e { error = e; throw e }
        }
    }

    public final func stackNew(string: String, url: URL) throws {
        try lock.withLock {
            do { pushStream(try SAXStringCharInputStream(string: string, url: url)) }
            catch let e { error = e; throw e }
        }
    }

    public final func stackNew(data: Data, url: URL) throws {
        try lock.withLock {
            do { pushStream(try SAXIConvCharInputStream(inputStream: InputStream(data: data), url: url)) }
            catch let e { error = e; throw e }
        }
    }

    public final func stackNew(url: URL) throws {
        try lock.withLock {
            do { try _stackNew(url: url) }
            catch let e { error = e; throw e }
        }
    }

    public final func stackNew(systemId: String) throws {
        try lock.withLock {
            do {
                guard let url = URL(string: systemId, relativeTo: baseURL) else { throw SAXError.MalformedURL(pos, url: systemId) }
                try _stackNew(url: url)
            }
            catch let e { error = e; throw e }
        }
    }

    @inlinable final func _stackNew(url: URL) throws {
        guard let inputStream = InputStream(url: url) else { throw SAXError.MalformedURL(pos, url: url.absoluteString) }
        pushStream(try SAXIConvCharInputStream(inputStream: inputStream, url: url))
    }

    @inlinable var hasChars: Bool {
        guard isGood && buffer.isEmpty else { return isGood }
        repeat {
            if charStream.hasCharsAvailable { return true }
        }
        while popStream()
        return false
    }

    @discardableResult @inlinable func popStream() -> Bool {
        guard let item = sstk.popLast() else { return false }
        charStream.close()
        (pos, charStream) = item
        return true
    }

    @inlinable final func pushStream(_ stream: SAXChildCharInputStream) {
        sstk <+ (pos, charStream)
        pos = (1, 1)
        charStream = stream
        charStream.open()
    }

    @inlinable final func pushChar(char: Character) -> Character {
        if let mi = mstk.last { mi.data <+ (pos, char) }
        textPositionUpdate(char, pos: &pos, tabWidth: tab)
        return char
    }

    @inlinable final func _close() {
        if status == .open {
            status = .closed
            charStream.close()
            for s in sstk { s.1.close() }
            for m in mstk { m.data.removeAll(keepingCapacity: false) }
            sstk.removeAll(keepingCapacity: false)
            mstk.removeAll(keepingCapacity: false)
            buffer.removeAll(keepingCapacity: false)
            pos = (0, 0)
            error = nil
        }
    }

    @inlinable final func _markSet() {
        if isGood { mstk <+ MarkItem(pos) }
    }

    @inlinable final func _markDelete() {
        if isGood { _ = mstk.popLast() }
    }

    @inlinable final func _markReturn() {
        if isGood, let mi = mstk.popLast() { pos = mi.pos; buffer.insert(contentsOf: mi.data.map({ $0.1 }), at: 0) }
    }

    @inlinable final func _append(to chars: inout [Character], maxLength: Int) throws -> Int {
        guard maxLength != 0 && isOpen else { return 0 }
        if let e = error { throw e }

        do {
            let ix = chars.endIndex
            let ln = ((maxLength < 0) ? Int.max : maxLength)
            let cc = _appendFromBuffer(chars: &chars, maxLength: ln)
            try _appendFromStream(chars: &chars, maxLength: ln, bufferCount: cc)
            pushChars(chars: chars, startIndex: ix)
            return chars.distance(from: ix, to: chars.endIndex)
        }
        catch let e { error = e; throw e }
    }

    @inlinable final func _appendFromStream(chars: inout [Character], maxLength ln: Int, bufferCount bc: Int) throws {
        var cc = bc
        while (cc < ln) && hasChars { cc += try charStream.append(to: &chars, maxLength: (ln - cc)) }
    }

    @inlinable final func _appendFromBuffer(chars: inout [Character], maxLength ln: Int) -> Int {
        let cc = min(ln, buffer.count)
        if cc > 0 {
            chars.append(contentsOf: buffer[0 ..< cc])
            buffer.removeSubrange(0 ..< cc)
        }
        return cc
    }

    @inlinable final func pushChars(chars: [Character], startIndex ix: Int) {
        if let mi = mstk.last { pushChars(chars: chars, startIndex: ix) { mi.data <+ (pos, $0); textPositionUpdate($0, pos: &pos, tabWidth: tab) } }
        else { pushChars(chars: chars, startIndex: ix) { textPositionUpdate($0, pos: &pos, tabWidth: tab) } }
    }

    @inlinable final func pushChars(chars: [Character], startIndex ix: Int, _ body: (Character) -> Void) {
        for ch in chars[ix ..< chars.endIndex] { body(ch) }
    }

    //@f:0
    @usableFromInline class MarkItem {
        @usableFromInline let pos:  TextPosition
        @usableFromInline var data: [(TextPosition, Character)] = []
        @usableFromInline init(_ pos: TextPosition) { self.pos = pos }
    }
    //@f:1
}
