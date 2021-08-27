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
    lazy var encodingName:      String        = { mutex.withLock { inputStream.encodingName } }()
    lazy var baseURL:           URL           = { mutex.withLock { docPosition.url.absoluteURL.deletingLastPathComponent() } }()
    lazy var filename:          String        = { mutex.withLock { docPosition.url.relativeString } }()
    var      markCount:         Int           { mutex.withLock { markStack.count } }
    var      isEOF:             Bool          { mutex.withLock { (buffer.isNotEmpty && inputStream.isEOF) } }
    var      hasCharsAvailable: Bool          { mutex.withLock { (buffer.isNotEmpty || inputStream.hasCharsAvailable) } }
    var      streamError:       Error?        { mutex.withLock { error } }
    var      streamStatus:      Stream.Status { mutex.withLock { ((error == nil) ? status : .error) } }

    private let inputStream:  SimpleIConvCharInputStream
    private let mutex:        MutexLock                  = MutexLock()
    private var status:       Stream.Status              = .notOpen
    private var error:        Error?                     = nil
    private var buffer:       [Character]                = []
    private var markStack:    [MarkItem]                 = []
    //@f:1

    convenience init(fileAtPath path: String, tabSize: Int8 = 4) throws {
        guard let strm = MarkInputStream(fileAtPath: path) else { throw StreamError.FileNotFound(description: path) }
        let url = URL(fileURLWithPath: path, relativeTo: URL.currentDirectoryURL)
        try self.init(byteStream: strm, url: url, tabSize: tabSize)
    }

    convenience init(url: URL, tabSize: Int8 = 4, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil) throws {
        guard let byteStream = MarkInputStream(url: url, options: options, authenticate: authenticate) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        try self.init(byteStream: byteStream, url: url, tabSize: tabSize)
    }

    convenience init(data: Data, url: URL? = nil, tabSize: Int8 = 4) throws {
        let byteStream = MarkInputStream(data: data)
        try self.init(byteStream: byteStream, url: url ?? URL.bogusURL(), tabSize: tabSize)
    }

    convenience init(inputStream: InputStream, url: URL, encodingName: String, tabSize: Int8) throws {
        if let bis = inputStream as? MarkInputStream { try self.init(byteStream: bis, url: url, tabSize: tabSize) }
        else { try self.init(byteStream: MarkInputStream(inputStream: inputStream, autoClose: true), url: url, tabSize: tabSize) }
    }

    init(byteStream: MarkInputStream, url: URL, tabSize: Int8) throws {
        do {
            byteStream.open()

            var encodingName = try { () throws -> String in
                // See if a web server is telling us what it thinks it is...
                if let txtEnc = (byteStream.property(forKey: .textEncodingNameKey) as? String)?.trimmed, txtEnc.isNotEmpty { return txtEnc }

                // Look for byte order marks...
                byteStream.markSet()
                defer { byteStream.markReturn() }

                var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 4)

                let res = byteStream.read(&bytes, maxLength: 4)
                if res < 0 { throw byteStream.streamError ?? StreamError.UnknownError() }
                if res < 4 { throw StreamError.UnexpectedEndOfInput() }

                // BOMs...
                if let t = bomInfo.first(where: { (bom) -> Bool in bytes[..<bom.bytes.count] == bom.bytes }) { return t.1 }

                // See if we can tell from any zero values in the first four bytes...
                if bytes[..<3] == [ 0, 0, 0 ] && bytes[3] != 0 { return "UTF-32BE" }
                if bytes[0] != 0 && bytes[1...] == [ 0, 0, 0 ] { return "UTF-32LE" }
                if bytes[0] == 0 && bytes[1] != 0 { return "UTF-16BE" }
                if bytes[0] != 0 && bytes[1] == 0 { return "UTF-16LE" }

                // Default to UTF-8
                return "UTF-8"
            }()

            if let xd = try XMLDecl(inputStream: byteStream, encodingName: encodingName) { encodingName = xd.encoding }

            self.docPosition = DocPosition(url: url, tabSize: tabSize)
            self.inputStream = SimpleIConvCharInputStream(inputStream: byteStream, encodingName: encodingName, autoClose: true)
        }
        catch let e {
            byteStream.close()
            throw e
        }
    }

    deinit {
        inputStream.close()
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

typealias BOMInfo = (bytes: [UInt8], name: String)

let bomInfo: [BOMInfo] = [
    (bytes: [ 0x00, 0x00, 0xfe, 0xff ], name: "UTF-32"),
    (bytes: [ 0xff, 0xfe, 0x00, 0x00 ], name: "UTF-32"),
    (bytes: [ 0x84, 0x31, 0x95, 0x33 ], name: "GB18030"),
    (bytes: [ 0xef, 0xbb, 0xbf ], name: "UTF-8"),
    (bytes: [ 0x2b, 0x2f, 0x76 ], name: "UTF-7"),
    (bytes: [ 0xfe, 0xff ], name: "UTF-16"),
    (bytes: [ 0xff, 0xfe ], name: "UTF-16"),
]
