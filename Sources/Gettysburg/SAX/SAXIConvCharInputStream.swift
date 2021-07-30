/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXIConvCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 29, 2021
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
import Chadakoin

class SAXIConvCharInputStream: SAXCharInputStream {
    //@f:0
    var      docPosition:       DocPosition
    lazy var baseURL:           URL           = { mutex.withLock { docPosition.url.baseURL ?? URL.currentDirectoryURL } }()
    lazy var filename:          String        = { mutex.withLock { docPosition.url.relativeString } }()
    var      markCount:         Int           { mutex.withLock { markStack.count } }
    var      isEOF:             Bool          { mutex.withLock { (buffer.isNotEmpty && inputStream.isEOF) } }
    var      hasCharsAvailable: Bool          { mutex.withLock { (buffer.isNotEmpty || inputStream.hasCharsAvailable) } }
    var      encodingName:      String        { mutex.withLock { (inputStream.encodingName) } }
    var      streamError:       Error?        { mutex.withLock { error } }
    var      streamStatus:      Stream.Status { mutex.withLock { ((error == nil) ? status : .error) } }

    let      inputStream: SimpleIConvCharInputStream
    let      mutex:       MutexLock                  = MutexLock()
    var      status:      Stream.Status              = .notOpen
    var      error:       Error?                     = nil
    var      buffer:      [Character]                = []
    var      markStack:   [MarkItem]                 = []
    //@f:1

    convenience init(fileAtPath path: String, tabSize: Int8 = 4) throws {
        let enc = try getEncodingName(filename: path)
        guard let strm = MarkInputStream(fileAtPath: path) else { throw StreamError.FileNotFound(description: path) }
        let url = URL(fileURLWithPath: path, relativeTo: URL.currentDirectoryURL)
        try self.init(inputStream: strm, url: url, encodingName: enc, tabSize: tabSize)
    }

    convenience init(url: URL, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil, tabSize: Int8 = 4) throws {
        let enc = try getEncodingName(url: url, options: options, authenticate: authenticate)
        guard let byteStream = MarkInputStream(url: url, options: options, authenticate: authenticate) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        try self.init(inputStream: byteStream, url: url, encodingName: enc, tabSize: tabSize)
    }

    convenience init(data: Data, url: URL? = nil, tabSize: Int8 = 4) throws {
        let enc        = try getEncodingName(data: data)
        let byteStream = MarkInputStream(data: data)
        try self.init(inputStream: byteStream, url: url ?? URL.bogusURL(), encodingName: enc, tabSize: tabSize)
    }

    init(inputStream: MarkInputStream, url: URL, encodingName: String, tabSize: Int8) throws {
        // See if we need to remove any BOM bytes from the input stream.
        try removeBOM(inputStream: inputStream, encodingName: encodingName)
        self.inputStream = SimpleIConvCharInputStream(inputStream: inputStream, encodingName: encodingName)
        self.docPosition = DocPosition(url: url, tabSize: tabSize)
    }

    func markSet() { mutex.withLock { _markSet() } }

    func markRelease() { mutex.withLock { _markRelease() } }

    func markReturn() { mutex.withLock { _markReturn() } }

    func markReset() { mutex.withLock { _markReturn(); _markSet() } }

    func markUpdate() { mutex.withLock { _markRelease(); _markSet() } }

    func markBackup(count: Int) -> Int {
        mutex.withLock {
            guard var ms = markStack.last else { return 0 }
            let cc = min(count, ms.chars.count)
            if cc > 0 {
                let range = ((ms.chars.endIndex - cc) ..< ms.chars.endIndex)
                buffer.insert(contentsOf: ms.chars[range], at: 0)
                ms.chars.removeSubrange(range)
                docPosition.position = ms.pos
                docPosition.update(ms.chars)
            }
            return cc
        }
    }

    func peek() throws -> Character? {
        try mutex.withLock {
            guard buffer.isEmpty else { return buffer[buffer.startIndex] }
            return try inputStream.peek()
        }
    }

    func read() throws -> Character? {
        try mutex.withLock {
            guard let ch = try _read() else { return nil }
            docPosition.update(ch)
            if var ms = markStack.last { ms.chars <+ ch }
            return ch
        }
    }

    func append(to chars: inout [Character], maxLength: Int) throws -> Int {
        try mutex.withLock {
            let len = ((maxLength < 0) ? Int.max : maxLength)
            guard len > 0 else { return 0 }

            let ix = chars.endIndex
            var cc = min(len, buffer.count)

            if cc > 0 {
                chars.append(contentsOf: buffer[buffer.startIndex ..< (buffer.startIndex + cc)])
                buffer.removeFirst(cc)
            }

            if cc < len { cc += try inputStream.append(to: &chars, maxLength: (len - cc)) }

            if cc > 0 {
                let out = chars[ix ..< chars.endIndex]
                docPosition.update(out)
                if var ms = markStack.last { ms.chars.append(contentsOf: out) }
            }

            return cc
        }
    }

    func open() {
        mutex.withLock {
            guard status == .notOpen else { return }
            status = .open
            inputStream.open()
            if let e = inputStream.streamError { error = e }
        }
    }

    func close() {
        mutex.withLock {
            guard status != .closed else { return }
            inputStream.close()
            buffer.removeAll(keepingCapacity: false)
            markStack.removeAll(keepingCapacity: false)
            error = nil
            status = .closed
        }
    }

    func lock() { mutex.lock() }

    func unlock() { mutex.unlock() }

    func withLock<T>(_ body: () throws -> T) rethrows -> T { try mutex.withLock { try body() } }

    private func _markSet() { markStack <+ MarkItem(pos: docPosition.position) }

    private func _markReturn() {
        guard var ms = markStack.popLast() else { return }
        buffer.insert(contentsOf: ms.chars, at: buffer.startIndex)
        docPosition.position = ms.pos
        ms.chars.removeAll(keepingCapacity: false)
    }

    private func _markRelease() {
        guard var ms = markStack.popLast() else { return }
        guard var ns = markStack.last else { return }
        ns.chars.append(contentsOf: ms.chars)
        ms.chars.removeAll(keepingCapacity: false)
    }

    private func _read() throws -> Character? {
        guard buffer.isEmpty else { return buffer.popFirst() }
        return try inputStream.read()
    }

    struct MarkItem {
        let pos:   TextPosition
        var chars: [Character] = []
    }
}
