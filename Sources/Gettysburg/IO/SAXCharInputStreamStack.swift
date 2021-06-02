/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStreamStack.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/1/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//******************************************************************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

open class SAXCharInputStreamStack: SAXCharInputStream {
    //@f:0
    @inlinable public var url:               URL           { lock.withLock { inputStream.url                                                                        } }
    @inlinable public var baseURL:           URL           { lock.withLock { inputStream.baseURL                                                                    } }
    @inlinable public var filename:          String        { lock.withLock { inputStream.filename                                                                   } }
    @inlinable public var docPosition:       DocPosition   { lock.withLock { isOpen ? inputStream.docPosition : DocPosition(line: 0, column: 0)                     } }
    @inlinable public var markCount:         Int           { lock.withLock { isOpen ? inputStream.markCount : 0                                                     } }
    @inlinable public var position:          TextPosition  { lock.withLock { isOpen ? inputStream.position : (0, 0)                                                 } }
    @inlinable public var encodingName:      String        { lock.withLock { inputStream.encodingName                                                               } }
    @inlinable public var streamError:       Error?        { lock.withLock { isOpen ? inputStream.streamError : nil                                                 } }
    @inlinable public var streamStatus:      Stream.Status { lock.withLock { isOpen ? inputStream.streamStatus : status                                             } }
    @inlinable public var isEOF:             Bool          { lock.withLock { isOpen && inputStream.isEOF                                                            } }
    @inlinable public var hasCharsAvailable: Bool          { lock.withLock { isOpen && inputStream.hasCharsAvailable                                                } }
    @inlinable public var tabWidth:          Int8          { get { lock.withLock { inputStream.tabWidth } } set { lock.withLock { inputStream.tabWidth = newValue } } }

    @usableFromInline var inputStream: SAXCharInputStream
    @usableFromInline var streamStack: [SAXCharInputStream] = []
    @usableFromInline let lock:        MutexLock            = MutexLock()
    @usableFromInline var status:      Stream.Status        = .notOpen
    @inlinable        var isOpen:      Bool                 { status == .open }
    //@f:1

    public init(initialInputStream: InputStream, url: URL) throws { self.inputStream = try SAXIConvCharInputStream(inputStream: initialInputStream, url: url) }

    @inlinable public func open() {
        lock.withLock {
            guard status == .notOpen else { return }
            status = .open
            if inputStream.streamStatus == .notOpen { inputStream.open() }
        }
    }

    @inlinable public func close() {
        lock.withLock {
            guard status == .open else { return }
            status = .closed
            inputStream.close()
        }
    }

    @inlinable public func read() throws -> Character? { try lock.withLock { isOpen ? try inputStream.read() : nil } }

    @inlinable public func append(to chars: inout [Character], maxLength: Int) throws -> Int { try lock.withLock { isOpen ? try inputStream.append(to: &chars, maxLength: maxLength) : 0 } }

    @inlinable public func markSet() { lock.withLock { if isOpen { inputStream.markSet() } } }

    @inlinable public func markReturn() { lock.withLock { if isOpen { inputStream.markReturn() } } }

    @inlinable public func markDelete() { lock.withLock { if isOpen { inputStream.markDelete() } } }

    @inlinable public func markReset() { lock.withLock { if isOpen { inputStream.markReset() } } }

    @inlinable public func markUpdate() { lock.withLock { if isOpen { inputStream.markUpdate() } } }

    @inlinable public func markBackup(count: Int = 1) -> Int { lock.withLock { isOpen ? inputStream.markBackup(count: count) : 0 } }

    open func pushStream(url: URL) throws {
        guard let inputStream = InputStream(url: url) else { throw SAXError.MalformedURL(description: url.absoluteString) }
        pushStream(inputStream: try SAXIConvCharInputStream(inputStream: inputStream, url: url))
    }

    open func pushStream(string: String, url: URL? = nil) throws {
        pushStream(inputStream: try SAXStringCharInputStream(string: string, url: url))
    }

    open func pushStream(data: Data, url: URL? = nil) throws {
        pushStream(inputStream: try SAXIConvCharInputStream(inputStream: InputStream(data: data), url: url))
    }

    open func pushStream(fileAtPath: String) throws {
        guard let inputStream = InputStream(fileAtPath: fileAtPath) else { throw StreamError.FileNotFound(description: fileAtPath) }
        pushStream(inputStream: try SAXIConvCharInputStream(inputStream: inputStream, url: GetFileURL(filename: fileAtPath)))
    }

    open func pushStream(inputStream: SAXCharInputStream) {
        lock.withLock {
            guard isOpen else { return }
            streamStack <+ self.inputStream
            self.inputStream = inputStream
            if self.inputStream.streamStatus == .notOpen { self.inputStream.open() }
        }
    }

    open func popStream() -> Bool {
        lock.withLock {
            guard isOpen, let s = streamStack.popLast() else { return false }
            inputStream.close()
            inputStream = s
            return true
        }
    }
}
