/*
 *     PROJECT: Gettysburg
 *    FILENAME: MultiSAXSimpleCharInputStreamImpl.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 4/14/21
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
/// Almost but not quite the root of all evil!!!!!
///
class MultiSAXSimpleCharInputStreamImpl: SAXSimpleCharInputStream {
    //@f:0
    var url:               URL           { lock.withLock { charStream.url                                                    } }
    var baseURL:           URL           { lock.withLock { charStream.baseURL                                                } }
    var filename:          String        { lock.withLock { charStream.filename                                               } }
    var encodingName:      String        { lock.withLock { charStream.encodingName                                           } }
    var tabWidth:          Int8          { get { lock.withLock { charStream.tabWidth } } set {}                                }
    var position:          TextPosition  { lock.withLock { (isOpen ? charStream.position : (0, 0))                           } }

    var isEOF:             Bool          { (streamStatus == .atEnd)                                                            }
    var hasCharsAvailable: Bool          { (streamStatus == .open)                                                             }
    var streamError:       Error?        { lock.withLock { (isOpen ? error : nil)                                            } }
    var streamStatus:      Stream.Status { lock.withLock { (isOpen ? (nErr ? (hasChars ? .open : .atEnd) : .error) : status) } }

    private var charStream:  SAXSimpleCharInputStream
    private var status:      Stream.Status              = .notOpen
    private var lock:        MutexLock                  = MutexLock()
    private var error:       Error?                     = nil
    private var streamStack: [SAXSimpleCharInputStream] = []

    private var isOpen:      Bool                       { (status == .open) }
    private var nErr:        Bool                       { (error == nil)    }
    //@f:1

    init(_ inputStream: InputStream, url: URL, skipXmlDecl: Bool) throws {
        charStream = try SAXSimpleIConvCharInputStream(inputStream: inputStream, url: url, skipXmlDecl: skipXmlDecl)
    }

    init(_ string: String, url: URL) throws {
        charStream = try SAXSimpleStringCharInputStream(string, url)
    }

    init(_ data: Data, url: URL, skipXMLDecl: Bool) throws {
        charStream = try SAXSimpleStringCharInputStream(data, url, skipXMLDeclaration: skipXMLDecl)
    }

    init(_ url: URL, skipXMLDecl: Bool) throws {
        guard let stream = InputStream(url: url) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        charStream = try SAXSimpleIConvCharInputStream(inputStream: stream, url: url, skipXmlDecl: skipXMLDecl)
    }

    func read() throws -> CharPos? {
        try lock.withLock {
            guard isOpen && nErr && hasChars else { return try defReturn(nil) }
            do { return try charStream.read() }
            catch let e { try handleCaught(e) }
        }
    }

    func append(to chars: inout [CharPos], maxLength: Int) throws -> Int {
        try lock.withLock {
            guard isOpen && nErr && hasChars else { return try defReturn(0) }
            do {
                var cc = 0
                let ln = fixLength(maxLength)

                while cc < ln {
                    let x = try charStream.append(to: &chars, maxLength: (ln - cc))
                    if x > 0 { cc += x }
                    else { guard popStream() else { break } }
                }

                return cc
            }
            catch let e { try handleCaught(e) }
        }
    }

    func open() {
        lock.withLock {
            guard (status == .notOpen) else { return }
            if charStream.streamStatus == .notOpen { charStream.open() }
            error = nil
            status = .open
        }
    }

    func close() {
        lock.withLock {
            guard isOpen else { return }
            repeat { charStream.close() } while popStream()
            error = nil
            status = .closed
        }
    }

    func pushStream(_ cs: SAXSimpleCharInputStream) throws {
        try lock.withLock {
            if cs.streamStatus == .notOpen { cs.open() }
            if let e = cs.streamError { throw e }
            streamStack <+ charStream
            charStream = cs
        }
    }

    func pushStream(_ inputStream: InputStream, url: URL) throws {
        try pushStream(SAXSimpleIConvCharInputStream(inputStream: inputStream, url: url, skipXmlDecl: true))
    }

    func pushStream(_ url: URL) throws {
        try pushStream(SAXSimpleIConvCharInputStream(url: url, skipXmlDecl: true))
    }

    func pushStream(_ string: String, url: URL) throws {
        try pushStream(SAXSimpleStringCharInputStream(string, url))
    }

    func pushStream(_ data: Data, url: URL) throws {
        try pushStream(SAXSimpleStringCharInputStream(data, url, skipXMLDeclaration: true))
    }

    private func popStream() -> Bool {
        guard let s = streamStack.popLast() else { return false }
        charStream.close()
        charStream = s
        error = charStream.streamError
        return true
    }

    private var hasChars: Bool {
        repeat { if charStream.hasCharsAvailable { return true } }
        while popStream()
        return false
    }

    private func handleCaught(_ e: Error) throws -> Never {
        error = e
        throw e
    }

    private func defReturn<T>(_ retValue: T) throws -> T {
        if let e = error { throw e }
        return retValue
    }
}
