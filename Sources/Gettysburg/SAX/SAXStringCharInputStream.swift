/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXStringCharInputStream.swift
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

class SAXStringCharInputStream: SAXCharInputStream {
    //@f:0
    lazy var baseURL:           URL           = { mutex.withLock { docPosition.url.baseURL ?? URL.currentDirectoryURL } }()
    lazy var filename:          String        = { mutex.withLock { docPosition.url.relativeString } }()
    var      docPosition:       DocPosition
    var      markCount:         Int           { mutex.withLock { markStack.count } }
    var      isEOF:             Bool          { mutex.withLock { idx == string.endIndex } }
    var      hasCharsAvailable: Bool          { !isEOF }
    let      encodingName:      String        = "UTF-8"
    let      streamError:       Error?        = nil
    let      streamStatus:      Stream.Status = .open

    let      string:            String
    var      idx:               String.Index
    var      markStack:         [MarkItem]    = []
    let      mutex:             MutexLock     = MutexLock()
    //@f:1

    init(string: String, url: URL? = nil, tabSize: Int8 = 4) {
        self.string = string
        self.idx = self.string.startIndex
        self.docPosition = DocPosition(url: url ?? URL.bogusURL(), tabSize: tabSize)
    }

    func markSet() { mutex.withLock { markStack <+ MarkItem(idx: idx, pos: docPosition.position) } }

    func markRelease() { mutex.withLock { _ = markStack.popLast() } }

    func markReturn() {
        mutex.withLock {
            if let ms = markStack.popLast() {
                idx = ms.idx
                docPosition.position = ms.pos
            }
        }
    }

    func markReset() {
        mutex.withLock {
            if let ms = markStack.last {
                idx = ms.idx
                docPosition.position = ms.pos
            }
            else {
                markStack <+ MarkItem(idx: idx, pos: docPosition.position)
            }
        }
    }

    func markUpdate() {
        mutex.withLock {
            _ = markStack.popLast()
            markStack <+ MarkItem(idx: idx, pos: docPosition.position)
        }
    }

    func markBackup(count: Int) -> Int {
        mutex.withLock {
            guard let ms = markStack.last else { return 0 }
            let cc = min(count, string.distance(from: ms.idx, to: idx))
            guard cc > 0 else { return 0 }
            string.formIndex(&idx, offsetBy: -cc)
            docPosition.position = ms.pos
            docPosition.update(string[ms.idx ..< idx])
            return cc
        }
    }

    func peek() throws -> Character? { mutex.withLock { idx < string.endIndex ? string[idx] : nil } }

    func read() throws -> Character? {
        mutex.withLock {
            guard idx < string.endIndex else { return nil }
            let ch = string[idx]
            string.formIndex(after: &idx)
            return ch
        }
    }

    func append(to chars: inout [Character], maxLength: Int) throws -> Int {
        mutex.withLock {
            let len     = (maxLength < 0 ? Int.max : maxLength)
            var cc: Int = 0
            for _ in (0 ..< len) {
                guard idx < string.endIndex else { break }
                chars.append(string[idx])
                string.formIndex(after: &idx)
                cc += 1
            }
            return cc
        }
    }

    func open() {}

    func close() {}

    func lock() { mutex.lock() }

    func unlock() { mutex.unlock() }

    func withLock<T>(_ body: () throws -> T) rethrows -> T { try mutex.withLock { try body() } }

    struct MarkItem {
        let idx: String.Index
        let pos: TextPosition
    }
}
