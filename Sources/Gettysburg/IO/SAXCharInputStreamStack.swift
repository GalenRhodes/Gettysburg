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
    @inlinable public var url:               URL           { withLock { inputStream.url                                                                        } }
    @inlinable public var baseURL:           URL           { withLock { inputStream.baseURL                                                                    } }
    @inlinable public var filename:          String        { withLock { inputStream.filename                                                                   } }
    @inlinable public var docPosition:       DocPosition   { withLock { isOpen ? inputStream.docPosition : DocPosition(line: 0, column: 0)                     } }
    @inlinable public var markCount:         Int           { withLock { isOpen ? inputStream.markCount : 0                                                     } }
    @inlinable public var position:          TextPosition  { withLock { isOpen ? inputStream.position : (0, 0)                                                 } }
    @inlinable public var encodingName:      String        { withLock { inputStream.encodingName                                                               } }
    @inlinable public var streamError:       Error?        { withLock { isOpen ? inputStream.streamError : nil                                                 } }
    @inlinable public var streamStatus:      Stream.Status { withLock { isOpen ? inputStream.streamStatus : status                                             } }
    @inlinable public var isEOF:             Bool          { withLock { isOpen && inputStream.isEOF                                                            } }
    @inlinable public var hasCharsAvailable: Bool          { withLock { isOpen && inputStream.hasCharsAvailable                                                } }
    @inlinable public var tabWidth:          Int8          { get { withLock { inputStream.tabWidth } } set { withLock { inputStream.tabWidth = newValue } } }

    @usableFromInline var inputStream: SAXCharInputStream
    @usableFromInline var streamStack: [SAXCharInputStream] = []
    @usableFromInline let lck:         MutexLock            = MutexLock()
    @usableFromInline var status:      Stream.Status        = .notOpen
    @inlinable        var isOpen:      Bool                 { status == .open }
    //@f:1

    public init(initialInputStream: InputStream, url: URL) throws { self.inputStream = try SAXIConvCharInputStream(inputStream: initialInputStream, url: url) }

    @inlinable public final func peek() throws -> Character? { try withLock { try inputStream.peek() } }

    @inlinable public final func lock() { lck.lock() }

    @inlinable public final func unlock() { lck.unlock() }

    @inlinable public final func withLock<T>(_ body: () throws -> T) rethrows -> T { try lck.withLock(body) }

    @inlinable public final func open() {
        withLock {
            guard status == .notOpen else { return }
            status = .open
            if inputStream.streamStatus == .notOpen { inputStream.open() }
        }
    }

    @inlinable public final func close() {
        withLock {
            guard status == .open else { return }
            status = .closed
            inputStream.close()
            while let s = streamStack.popLast() {
                inputStream = s
                inputStream.close()
            }
        }
    }

    @inlinable public final func read() throws -> Character? { try withLock { isOpen ? try inputStream.read() : nil } }

    @inlinable public final func append(to chars: inout [Character], maxLength: Int) throws -> Int { try withLock { isOpen ? try inputStream.append(to: &chars, maxLength: maxLength) : 0 } }

    @inlinable public final func markSet() { withLock { if isOpen { inputStream.markSet() } } }

    @inlinable public final func markReturn() { withLock { if isOpen { inputStream.markReturn() } } }

    @inlinable public final func markDelete() { withLock { if isOpen { inputStream.markDelete() } } }

    @inlinable public final func markReset() { withLock { if isOpen { inputStream.markReset() } } }

    @inlinable public final func markUpdate() { withLock { if isOpen { inputStream.markUpdate() } } }

    @discardableResult @inlinable public final func markBackup(count: Int = 1) -> Int {
        withLock {
            if isOpen {
                return inputStream.markBackup(count: count)
            }
            else {
                return 0
            }
            // isOpen ? inputStream.markBackup(count: count) : 0
        }
    }

    open func pushStream(url: URL) throws {
        guard let inputStream = InputStream(url: url) else { throw SAXError.getMalformedURL(description: url.absoluteString) }
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
        withLock {
            guard isOpen else { return }
            streamStack <+ self.inputStream
            self.inputStream = inputStream
            if self.inputStream.streamStatus == .notOpen { self.inputStream.open() }
        }
    }

    open func popStream() -> Bool {
        withLock {
            guard isOpen, let s = streamStack.popLast() else { return false }
            inputStream.close()
            inputStream = s
            return true
        }
    }
}
