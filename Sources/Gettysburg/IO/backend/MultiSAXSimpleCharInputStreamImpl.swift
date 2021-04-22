/*=============================================================================================================================================================================*//*
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
    internal var streamStatus:      Stream.Status { (isOpen ? (hasError ? .error : (hasChars ? .open : .atEnd)) : status) }
    internal var isEOF:             Bool          { (streamStatus == .atEnd)                                              }
    internal var hasCharsAvailable: Bool          { (isGood && hasChars)                                                  }
    internal var tabWidth:          Int8          { get { charStream.tabWidth } set{ charStream.tabWidth = newValue }     }
    internal var streamError:       Error?        { error                                                                 }
    internal var encodingName:      String        { charStream.encodingName                                               }
    internal var url:               URL           { charStream.url                                                        }
    internal var baseURL:           URL           { charStream.baseURL                                                    }
    internal var filename:          String        { charStream.filename                                                   }
    internal var position:          TextPosition  { charStream.position                                                   }

    private var sStack:     [SAXSimpleCharInputStream] = []
    private var status:     Stream.Status              = .notOpen
    private var error:      Error?                     = nil
    private var charStream: SAXSimpleCharInputStream

    private var hasError: Bool { (error != nil)        }
    private var isOpen:   Bool { (status == .open)     }
    private var isGood:   Bool { (isOpen && !hasError) }
    //@f:1

    init(_ inputStream: InputStream, _ url: URL) throws {
        self.charStream = try SAXSimpleIConvCharInputStream(inputStream: inputStream, url: url)
    }

    deinit { close() }

    func read() throws -> CharPos? {
        if let e = error { throw e }
        guard isOpen else { return nil }

        do {
            repeat {
                if let ch = try charStream.read() { return ch }
            }
            while popStream()
            return nil
        }
        catch let e {
            error = e
            throw e
        }
    }

    func append(to chars: inout [CharPos], maxLength: Int) throws -> Int {
        if let e = error { throw e }
        guard isOpen && maxLength != 0 else { return 0 }

        do {
            let ln = fixLength(maxLength)
            var cc = 0

            while cc < ln {
                let x = try rd(&chars, (ln - cc))
                guard x > 0 else { break }
                cc += x
            }

            return cc
        }
        catch let e {
            error = e
            throw e
        }
    }

    func open() {
        if status == .notOpen {
            openChildStream()
            sStack.removeAll()
            error = nil
            status = .open
        }
    }

    func close() {
        if status == .open {
            status = .closed
            error = nil
            for s in sStack { s.close() }
            sStack.removeAll()
            charStream.close()
        }
    }

    func pushStream(_ charStream: SAXSimpleCharInputStream) {
        if isGood {
            sStack <+ self.charStream
            let tw = self.charStream.tabWidth
            self.charStream = charStream
            self.charStream.tabWidth = tw
            openChildStream()
        }
    }

    private func popStream() -> Bool {
        guard isGood else { return false }
        guard let st = sStack.popLast() else { return false }
        let tw = charStream.tabWidth
        charStream.close()
        charStream = st
        charStream.tabWidth = tw
        return true
    }

    private func rd(_ chars: inout [CharPos], _ maxLength: Int) throws -> Int {
        repeat {
            let x = try charStream.append(to: &chars, maxLength: maxLength)
            if x > 0 { return x }
        }
        while popStream()
        return 0
    }

    private func openChildStream() {
        charStream.open()
        if let e = charStream.streamError { error = e }
    }

    private var hasChars: Bool {
        guard isGood else { return false }
        var has = charStream.hasCharsAvailable

        while !has {
            guard popStream() else { return false }
            has = charStream.hasCharsAvailable
        }

        return has
    }
}

