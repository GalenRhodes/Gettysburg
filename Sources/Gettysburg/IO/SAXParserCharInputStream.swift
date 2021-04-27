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
    @Atomic public private(set) var url:          URL
    @Atomic public private(set) var encodingName: String
    @Atomic public private(set) var position:     TextPosition = (0, 0)

    public var markCount:    Int           { lock.withLock { markStack.count                                                                                             } }
    public var streamError:  Error?        { lock.withLock { ((isOpen && buffer.isEmpty) ? charStream.streamError : nil)                                                 } }
    public var streamStatus: Stream.Status { lock.withLock { (isOpen ? (hasBChars ? .open : (nErr ? (charStream.hasCharsAvailable ? .open : .atEnd) : .error)) : status) } }
    public var tabWidth:     Int8          { get { lock.withLock { charStream.tabWidth } } set { lock.withLock { charStream.tabWidth = newValue } }                        }

    public var baseURL:           URL    { url.deletingLastPathComponent() }
    public var filename:          String { url.lastPathComponent           }
    public var isEOF:             Bool   { (streamStatus == .atEnd)        }
    public var hasCharsAvailable: Bool   { (streamStatus == .open)         }
    public let parser:            SAXParser

    private let lock:       Conditional   = Conditional()
    private var status:     Stream.Status = .notOpen
    private var markStack:  [MarkItem]    = []
    private var buffer:     [MarkData]    = []
    private let charStream: MultiSAXSimpleCharInputStreamImpl

    private var isOpen:    Bool { (status == .open)                     }
    private var nErr:      Bool { (charStream.streamError == nil)       }
    private var hasBChars: Bool { !buffer.isEmpty                       }
    private var isReady:   Bool { (isOpen && (nErr || hasBChars))       }
    //@f:1

    public init(inputStream: InputStream, url: URL, parser: SAXParser) throws {
        self.parser = parser
        self.charStream = try MultiSAXSimpleCharInputStreamImpl(inputStream, url: url, skipXmlDecl: false)
        self.url = charStream.url
        self.encodingName = charStream.encodingName
    }

    public init(string: String, url: URL, parser: SAXParser) throws {
        self.parser = parser
        self.charStream = try MultiSAXSimpleCharInputStreamImpl(string, url: url)
        self.url = charStream.url
        self.encodingName = charStream.encodingName
    }

    public init(data: Data, url: URL, parser: SAXParser) throws {
        self.parser = parser
        self.charStream = try MultiSAXSimpleCharInputStreamImpl(data, url: url, skipXMLDecl: false)
        self.url = charStream.url
        self.encodingName = charStream.encodingName
    }

    public init(url: URL, parser: SAXParser) throws {
        self.parser = parser
        self.charStream = try MultiSAXSimpleCharInputStreamImpl(url, skipXMLDecl: false)
        self.url = charStream.url
        self.encodingName = charStream.encodingName
    }

    public func open() {
        lock.withLock {
            guard status == .notOpen else { return }
            if charStream.streamStatus == .notOpen { charStream.open() }
            setStreamFields()
            status = .open
        }
    }

    public func close() {
        lock.withLock {
            guard isOpen else { return }
            markStack.forEach { $0.data.removeAll(keepingCapacity: false) }
            markStack.removeAll(keepingCapacity: false)
            buffer.removeAll(keepingCapacity: false)
            charStream.close()
            status = .closed
            position = (0, 0)
        }
    }

    public func read() throws -> Character? {
        try lock.withLock {
            guard isOpen else { return nil }
            return try (charFromBuffer() ?? charFromStream())
        }
    }

    public func append(to chars: inout [Character], maxLength: Int) throws -> Int {
        try lock.withLock {
            guard isOpen && (maxLength != 0) else { return 0 }
            let ln = fixLength(maxLength)
            var cc = readFromBuffer(to: &chars, maxLength: ln)
            if cc < ln { try readFromStream(to: &chars, maxLength: ln, currentCount: &cc) }
            return cc
        }
    }

    //@f:0
    public func markSet()    { lock.withLock { if isReady { setMark() }                                                                                  } }

    public func markDelete() { lock.withLock { if isReady { _ = markStack.popLast() }                                                                    } }

    public func markReturn() { lock.withLock { if isReady, let mi = markStack.popLast() { returnToMark(mi) }                                             } }

    public func markReset()  { lock.withLock { if isReady { if let mi = markStack.last { returnToMark(mi) } else { setMark() } }                         } }

    public func markUpdate() { lock.withLock { if isReady { if let mi = markStack.last { mi.data.removeAll(keepingCapacity: true) } else { setMark() } } } }
    //@f:1

    public func markBackup(count: Int) -> Int {
        lock.withLock {
            guard isReady && (count > 0) else { return 0 }
            guard let mi = markStack.last else { return 0 }
            return backupMark(count, mi)
        }
    }

    public func stackNew(string: String, url: URL) throws {
        try lock.withLock {
            if isReady {
                try charStream.pushStream(string, url: url)
                if buffer.isEmpty { setStreamFields() }
            }
        }
    }

    public func stackNew(data: Data, url: URL) throws {
        try lock.withLock {
            if isReady {
                try charStream.pushStream(data, url: url)
                if buffer.isEmpty { setStreamFields() }
            }
        }
    }

    public func stackNew(systemId: String) throws {
        try lock.withLock {
            if isReady {
                try charStream.pushStream(GetURL(string: systemId, relativeTo: baseURL))
                if buffer.isEmpty { setStreamFields() }
            }
        }
    }

    public func stackNew(inputStream: InputStream, url: URL) throws {
        try lock.withLock {
            if isReady {
                try charStream.pushStream(inputStream, url: url)
                if buffer.isEmpty { setStreamFields() }
            }
        }
    }

    public func stackNew(url: URL) throws {
        try lock.withLock {
            if isReady {
                try charStream.pushStream(url)
                if buffer.isEmpty { setStreamFields() }
            }
        }
    }

    private func setMark() {
        markStack <+ MarkItem(position, url, encodingName)
    }

    private func returnToMark(_ mi: MarkItem) {
        guard !mi.data.isEmpty else { return }
        buffer.insert(contentsOf: mi.data, at: 0)
        setStreamFields(mi)
        mi.data.removeAll(keepingCapacity: false)
    }

    private func backupMark(_ count: Int, _ mi: MarkItem) -> Int {
        let cc = min(count, mi.data.count)

        if (cc > 0) {
            let x = (mi.data.endIndex - cc)
            let r = (x ..< mi.data.endIndex)

            if x > 0 { setStreamFields(mi.data[x - 1]) }
            else { setStreamFields(mi) }

            buffer.insert(contentsOf: mi.data[r], at: 0)
            mi.data.removeSubrange(r)
        }

        return cc
    }

    private func setStreamFields(_ p: TextPosition? = nil) {
        (position, url, encodingName) = ((p ?? charStream.position), charStream.url, charStream.encodingName)
    }

    private func setStreamFields(_ d: MarkData) {
        (position, url, encodingName) = (d.charPos.pos, d.url, d.encodingName)
    }

    private func setStreamFields(_ mi: MarkItem) {
        (position, url, encodingName) = (mi.pos, mi.url, mi.encodingName)
    }

    private func charFromBuffer() throws -> Character? {
        if let ch = buffer.popFirst() {
            setStreamFields(ch)
            return ch.charPos.char
        }
        return nil
    }

    private func charFromStream() throws -> Character? {
        if let ch = try charStream.read() {
            setStreamFields(ch.pos)
            return ch.char
        }
        return nil
    }

    private func readFromBuffer(to chars: inout [Character], maxLength ln: Int) -> Int {
        let cc = min(ln, buffer.count)

        if cc > 0 {
            let rn = (0 ..< cc)
            chars.append(contentsOf: buffer[rn].map { $0.charPos.char })
            setStreamFields(buffer[cc - 1])
            buffer.removeSubrange(rn)
        }

        return cc
    }

    private func readFromStream(to chars: inout [Character], maxLength ln: Int, currentCount cc: inout Int) throws {
        var carr: [CharPos] = []
        setStreamFields()

        repeat {
            let x = try charStream.append(to: &carr, maxLength: (ln - cc))
            guard x > 0 else { break }
            cc += x
        }
        while cc < ln

        if let el = carr.last {
            chars.append(contentsOf: carr.map { $0.char })
            position = el.pos
        }
    }

    private class MarkData {
        let charPos:      CharPos
        let url:          URL
        let encodingName: String

        init(charPos: CharPos, url: URL, encodingName: String) {
            self.charPos = charPos
            self.url = url
            self.encodingName = encodingName
        }
    }

    private class MarkItem {
        let pos:          TextPosition
        let url:          URL
        let encodingName: String
        var data:         [MarkData] = []

        fileprivate init(_ pos: TextPosition, _ url: URL, _ encodingName: String) {
            self.pos = pos
            self.url = url
            self.encodingName = encodingName
        }
    }
}
