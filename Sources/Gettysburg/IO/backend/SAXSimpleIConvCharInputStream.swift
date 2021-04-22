/*=============================================================================================================================================================================*//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXSimpleCharInputStreamImpl.swift
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
/// The root of all evil!!!!!
///
class SAXSimpleIConvCharInputStream: SAXSimpleCharInputStream {
    //@f:0
    internal let url:               URL
    internal let baseURL:           URL
    internal let filename:          String
    internal var tabWidth:          Int8          { get { lock.withLock { tab } } set { lock.withLock { tab = newValue }                                                    } }
    internal var isEOF:             Bool          { (streamStatus == .atEnd)                                                                                                  }
    internal var hasCharsAvailable: Bool          { lock.withLock { (isOpen && hasChars)                                                                                    } }
    internal var encodingName:      String        { lock.withLock { charStream.encodingName                                                                                 } }
    internal var streamStatus:      Stream.Status { lock.withLock { (isOpen ? (buffer.isEmpty ? ((error == nil) ? (isRunning ? .open : .atEnd) : .error) : .open) : status) } }
    internal var streamError:       Error?        { lock.withLock { ((isOpen && hasError) ? error : nil)                                                                    } }
    internal var position:          TextPosition  { lock.withLock { pos                                                                                                     } }

    private      let charStream:  SimpleCharInputStream
    private      let lock:        Conditional           = Conditional()
    private      var tab:         Int8                  = 4
    private      var pos:         TextPosition          = (0, 0)
    private      var error:       Error?                = nil
    private      var status:      Stream.Status         = .notOpen
    private      var buffer:      [Character]           = []
    private      var isRunning:   Bool                  = false
    private      var isWaiting:   Bool                  = false
    private      let skipXmlDecl: Bool
    private lazy var queue:       DispatchQueue         = DispatchQueue(label: UUID().uuidString, qos: .utility, autoreleaseFrequency: .workItem)

    private      var isOpen:      Bool                  { (status == .open)                                         }
    private      var hasChars:    Bool                  { (buffer.isNotEmpty || (isRunning && (error == nil)))      }
    private      var hasError:    Bool                  { (buffer.isEmpty && (error != nil))                        }
    //@f:1

    init(charStream: SimpleCharInputStream, url: URL, skipXmlDecl: Bool = false) throws {
        self.charStream = charStream
        (self.url, baseURL, filename) = try GetBaseURLAndFilename(url: url)
        self.skipXmlDecl = skipXmlDecl
    }

    convenience init(inputStream: InputStream, url: URL, skipXmlDecl: Bool = false) throws {
        let inputStream = ((inputStream as? MarkInputStream) ?? MarkInputStream(inputStream: inputStream))
        try self.init(charStream: SimpleIConvCharInputStream(inputStream: inputStream, encodingName: try getCharacterEncoding(inputStream)), url: url, skipXmlDecl: skipXmlDecl)
    }

    convenience init(url: URL, skipXmlDecl: Bool = false) throws {
        guard let input = MarkInputStream(url: url) else { throw SAXError.MalformedURL(url.absoluteString) }
        try self.init(inputStream: input, url: url, skipXmlDecl: skipXmlDecl)
    }

    deinit { close() }

    private var keepWaiting: Bool { (isOpen && buffer.isEmpty && isRunning && (error == nil)) }

    func read() throws -> CharPos? {
        try lock.withLock {
            while keepWaiting { lock.broadcastWait() }
            guard isOpen else { return nil }
            guard let ch = buffer.popFirst() else {
                if let e = error { throw e }
                return nil
            }
            let r = (ch, pos)
            textPositionUpdate(ch, pos: &pos, tabWidth: tab)
            return r
        }
    }

    func append(to chars: inout [CharPos], maxLength: Int) throws -> Int {
        try lock.withLock {
            var cc = 0
            let ln = fixLength(maxLength)

            while cc < ln {
                while keepWaiting { lock.broadcastWait() }
                guard isOpen else { break }
                guard buffer.count > 0 else {
                    if let e = error { throw e }
                    break
                }
                let i = min((ln - cc), buffer.count)
                let r = (0 ..< i)
                for ch in buffer[r] {
                    chars <+ (ch, pos)
                    textPositionUpdate(ch, pos: &pos, tabWidth: tab)
                }
                buffer.removeSubrange(r)
                cc += i
            }

            return cc
        }
    }

    func open() {
        lock.withLock {
            if status == .notOpen {
                error = nil
                pos = (1, 1)
                status = .open
                isRunning = true
                isWaiting = false
                buffer.removeAll()
                queue.async { [weak self] in if let s = self { s.readThread() } }
            }
        }
    }

    func close() {
        lock.withLock {
            if status == .open {
                status = .closed
                isWaiting = false
                while isRunning { lock.broadcastWait() }
                buffer.removeAll()
                pos = (0, 0)
                error = nil
            }
        }
    }

    private var isGood: Bool { (isOpen && (error == nil)) }

    private func readThread() {
        lock.withLock {
            do {
                if charStream.streamStatus == .notOpen { charStream.open() }
                defer {
                    isRunning = false
                    charStream.close()
                }

                if let e = charStream.streamError { throw e }

                while isGood {
                    while isGood && (isWaiting || buffer.count >= 65_536) { lock.broadcastWait() }
                    guard try isGood && (charStream.append(to: &buffer, maxLength: 1_024) > 0) else { break }
                }
            }
            catch let e {
                error = e
            }
        }
    }
}

/*===============================================================================================================================================================================*/
/// The bytes that comprise the `UTF-32BE` ~Byte Order Mark~.
///
private let BOM32BE: [UInt8] = [ 0, 0, 0xfe, 0xff ]
/*===============================================================================================================================================================================*/
/// The bytes that comprise the `UTF-32LE` ~Byte Order Mark~.
///
private let BOM32LE: [UInt8] = [ 0xff, 0xfe, 0, 0 ]

/*===============================================================================================================================================================================*/
/// Determine the character encoding.
///
/// - Parameter istr: the input stream.
/// - Returns: The name of the character encoding.
/// - Throws: If an I/O error occurs or the encoding found is not supported.
///
func getCharacterEncoding(_ istr: MarkInputStream) throws -> String { try getCharacterEncodingFromXMLDecl(istr, guessedEncoding: try guessCharacterEncoding(istr)) }

/*===============================================================================================================================================================================*/
/// Try to determine the character encoding from the first few bytes of the input stream. If it cannot determine then it defaults to `UTF-8`.
///
/// - Parameter inputStream: the input stream.
/// - Returns: The name of the character encoding.
/// - Throws: If an I/O error occurs.
///
private func guessCharacterEncoding(_ inputStream: MarkInputStream) throws -> String {
    if inputStream.streamStatus == .notOpen { inputStream.open() }
    inputStream.markSet()
    defer { inputStream.markReturn() }

    var buffer: [UInt8] = [ 0, 0, 0, 0 ]
    guard inputStream.read(&buffer, maxLength: 4) == 4 else { throw inputStream.streamError ?? StreamError.UnexpectedEndOfInput() }

    if buffer == BOM32BE || buffer == BOM32LE { return "UTF-32" }
    if buffer[0 ..< 2] == BOM32BE[2 ..< 4] || buffer[0 ..< 2] == BOM32LE[0 ..< 2] { return "UTF-16" }

    if buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0 { return "UTF-32BE" }
    if buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0 { return "UTF-32LE" }

    if buffer[0] == 0 && buffer[1] != 0 && buffer[2] == 0 && buffer[3] != 0 { return "UTF-16BE" }
    if buffer[0] != 0 && buffer[1] == 0 && buffer[2] != 0 && buffer[3] == 0 { return "UTF-16LE" }

    return "UTF-8"
}

/*===============================================================================================================================================================================*/
/// Attempt to read the XML Declaration from the input stream to determine the character encoding.
///
/// - Parameters:
///   - inputStream: the input stream.
///   - guessedEncoding: the character encoding guessed in the `guessCharacterEncoding(_:)` function.
/// - Returns: the character encoding found in the XML Declaration or the guessed encoding if the file does not have an XML Declaration or the XML Declaration does not specify the
///            encoding.
/// - Throws: If an I/O error occurs of the encoding found in the XML Declaration is not supported.
///
private func getCharacterEncodingFromXMLDecl(_ inputStream: MarkInputStream, guessedEncoding: String) throws -> String {
    inputStream.markSet()
    defer { inputStream.markReturn() }

    let charStream = IConvCharInputStream(inputStream: inputStream, encodingName: guessedEncoding, autoClose: false)

    charStream.open()
    defer { charStream.close() }

    let str = try charStream.readString(count: 6, errorOnEOF: false)

    if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
        let xmlDecl = try charStream.readUntil(found: "?>")

        if let regex = RegularExpression(pattern: "\\s(?:encoding)=\"([^\"]+)\"") {

            if let match = regex.firstMatch(in: xmlDecl), let enc = match[1].subString?.uppercased(), enc != guessedEncoding {
                let fin = getFinalEncoding(guessedEncoding: guessedEncoding, xmlDeclEncoding: enc)
                guard IConv.encodingsList.contains(fin) else { throw SAXError.UnsupportedCharacterEncoding(1, 1, description: "Unsupported Character Encoding: \(fin)") }
                return fin
            }
        }
    }

    return guessedEncoding
}

/*===============================================================================================================================================================================*/
/// Decide between the guessed encoding and the encoding found in the XML Declaration.
///
/// - Parameters:
///   - guessedEncoding: the guessed encoding.
///   - xmlDeclEncoding: the encoding found in the XML Declaration.
/// - Returns: the final encoding.
///
private func getFinalEncoding(guessedEncoding: String, xmlDeclEncoding: String) -> String {
    switch guessedEncoding {
        case "UTF-32", "UTF-32BE", "UTF-32LE": return (xmlDeclEncoding.hasPrefix("UTF-32") ? guessedEncoding : xmlDeclEncoding);
        case "UTF-16", "UTF-16BE", "UTF-16LE": return (xmlDeclEncoding.hasPrefix("UTF-16") ? guessedEncoding : xmlDeclEncoding);
        default: return xmlDeclEncoding
    }
}
