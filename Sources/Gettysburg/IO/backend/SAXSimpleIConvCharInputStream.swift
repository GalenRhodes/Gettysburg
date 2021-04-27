/*
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
/// A Regular Expression pattern for identifying the XML Declaration.
///
let XmlDeclPrefixPattern:     String = "\\A\\<\\?(?i:xml)\\s"
let EncodingParameterPattern: String = "\\s(?:encoding)=\"([^\"]+)\""
let ProcInstrCloser:          String = "?>"
let MaxReadAhead                     = 65536
let ReadBlockSize                    = 1024

/*===============================================================================================================================================================================*/
/// The root of all evil!!!!!
///
class SAXSimpleIConvCharInputStream: SAXSimpleCharInputStream {
    //@f:0
    let url:      URL
    let baseURL:  URL
    let filename: String

    var tabWidth:          Int8          { get { lock.withLock { tab } } set {}                                                                            }
    var isEOF:             Bool          { lock.withLock { (isOpen && buffer.isEmpty && nErr && !isRunning)                                              } }
    var hasCharsAvailable: Bool          { lock.withLock { (isOpen && (!buffer.isEmpty || (isRunning && nErr)))                                          } }
    var encodingName:      String        { lock.withLock { charStream.encodingName                                                                       } }
    var streamStatus:      Stream.Status { lock.withLock { (isOpen ? (buffer.isEmpty ? (nErr ? (isRunning ? .open : .atEnd) : .error) : .open) : status) } }
    var streamError:       Error?        { lock.withLock { ((isOpen && buffer.isEmpty) ? error : nil)                                                    } }
    var position:          TextPosition  { lock.withLock { pos                                                                                           } }

    private      let charStream:  SimpleCharInputStream
    private      let skipXmlDecl: Bool
    private      let lock:        Conditional       = Conditional()
    private      let tab:         Int8              = 4
    private      var status:      Stream.Status     = .notOpen
    private      var error:       Error?            = nil
    private      var pos:         TextPosition      = (1, 1)
    private      var buffer:      [CharPos]         = []
    private      var isRunning:   Bool              = false
    private      let isReading:   AtomicValue<Bool> = AtomicValue<Bool>(initialValue: false)
    private lazy var queue:       DispatchQueue     = DispatchQueue(label: UUID().uuidString, qos: .utility, autoreleaseFrequency: .workItem)

    private      var isOpen:      Bool              { (status == .open)                               }
    private      var nErr:        Bool              { (error == nil)                                  }
    private      var wait:        Bool              { (isOpen && buffer.isEmpty && nErr && isRunning) }
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
        guard let input = MarkInputStream(url: url) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        try self.init(inputStream: input, url: url, skipXmlDecl: skipXmlDecl)
    }

    convenience init(filename: String, skipXmlDecl: Bool) throws {
        try self.init(url: GetFileURL(filename: filename), skipXmlDecl: skipXmlDecl)
    }

    deinit { close() }

    func read() throws -> CharPos? {
        try isReading.waitUntil(valueIs: { !$0 }, thenWithValueSetTo: true) {
            try lock.withLock {
                while wait { lock.broadcastWait() }
                guard isOpen else { return nil }
                guard let ch = buffer.popFirst() else { if let e = error { throw e }; return nil }

                pos = nextCharPosition(currentPosition: ch.pos, character: ch.char, tabWidth: tab)
                return ch
            }
        }
    }

    func append(to chars: inout [CharPos], maxLength: Int) throws -> Int {
        try isReading.waitUntil(valueIs: { !$0 }, thenWithValueSetTo: true) {
            try lock.withLock {
                let ln = fixLength(maxLength)
                var cc = 0

                while cc < ln {
                    while wait { lock.broadcastWait() }
                    guard isOpen else { break }

                    let bc = buffer.count
                    guard bc > 0 else { if let e = error { throw e }; break }

                    let sz = min(bc, (ln - cc))
                    let ch = buffer[sz - 1]
                    let rn = (0 ..< sz)

                    chars.append(contentsOf: buffer[rn])
                    buffer.removeSubrange(rn)
                    pos = nextCharPosition(currentPosition: ch.pos, character: ch.char, tabWidth: tab)
                    cc += sz
                }

                return cc
            }
        }
    }

    func open() {
        lock.withLock {
            guard (status == .notOpen) else { return }
            buffer.removeAll(keepingCapacity: true)
            isRunning = true
            isReading.value = false
            status = .open
            pos = (1, 1)
            error = nil
            queue.async { [weak self] in if let s = self { s.readThread() } }
        }
    }

    func close() {
        lock.withLock {
            guard isOpen else { return }
            status = .closed
            while isRunning { lock.broadcastWait() }
            buffer.removeAll(keepingCapacity: false)
            pos = (0, 0)
            error = nil
        }
    }

    private func readThread() {
        lock.withLock {
            do {
                defer { isRunning = false }

                guard isOpen else { return }
                if charStream.streamStatus == .notOpen { charStream.open() }
                defer { charStream.close() }
                if let er = charStream.streamError { throw er }

                var readBlock: [Character]  = []
                var readPos:   TextPosition = (1, 1)

                if skipXmlDecl { readPos = try skipXmlDeclaration() }

                while true {
                    while isOpen && (buffer.count >= MaxReadAhead) { lock.broadcastWait() }
                    guard isOpen else { break }
                    let cc = try charStream.read(chars: &readBlock, maxLength: ReadBlockSize)
                    guard cc > 0 else { break }
                    copyToBuffer(readBlock, &readPos)
                    if isReading.value { lock.broadcastWait() }
                }
            }
            catch let e {
                error = e
                #if DEBUG
                    print("Caught error: \(e)")
                #endif
            }
        }
    }

    private func skipXmlDeclaration() throws -> TextPosition {
        var chars: [Character]  = []
        var rpos:  TextPosition = (1, 1)

        for _ in (0 ..< 6) {
            guard let ch = try charStream.read() else {
                rpos = (1, 1)
                copyToBuffer(chars, &rpos)
                return rpos
            }
            chars <+ ch
            textPositionUpdate(ch, pos: &rpos, tabWidth: tab)
        }

        if try String(chars).matches(pattern: XmlDeclPrefixPattern) {
            var lastChar: Character = chars.last!
            repeat {
                guard let ch = try charStream.read() else { throw SAXError.UnexpectedEndOfInput(rpos) }
                textPositionUpdate(ch, pos: &rpos, tabWidth: tab)
                if ch == ">" && lastChar == "?" { return rpos }
                lastChar = ch
            }
            while true
        }
        else {
            rpos = (1, 1)
            copyToBuffer(chars, &rpos)
            return rpos
        }
    }

    private func copyToBuffer(_ readBlock: [Character], _ readPos: inout TextPosition) {
        readBlock.forEach { ch in
            buffer <+ (ch, readPos)
            textPositionUpdate(ch, pos: &readPos, tabWidth: tab)
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

    if buffer == BOM32BE || buffer == BOM32LE { return UTF_32 }
    if buffer[0 ..< 2] == BOM32BE[2 ..< 4] || buffer[0 ..< 2] == BOM32LE[0 ..< 2] { return UTF_16 }

    if buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0 { return UTF_32BE }
    if buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0 { return UTF_32LE }

    if buffer[0] == 0 && buffer[1] != 0 && buffer[2] == 0 && buffer[3] != 0 { return UTF_16BE }
    if buffer[0] != 0 && buffer[1] == 0 && buffer[2] != 0 && buffer[3] == 0 { return UTF_16LE }

    return UTF_8
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

    guard try charStream.readString(count: 6, errorOnEOF: false).matches(pattern: XmlDeclPrefixPattern) else { return guessedEncoding }
    guard let regex = RegularExpression(pattern: EncodingParameterPattern) else { return guessedEncoding }
    guard let match = regex.firstMatch(in: try charStream.readUntil(found: ProcInstrCloser)) else { return guessedEncoding }
    guard let enc = match[1].subString?.uppercased() else { return guessedEncoding }
    guard (enc != guessedEncoding) else { return guessedEncoding }

    let fin = getFinalEncoding(guessedEncoding: guessedEncoding, xmlDeclEncoding: enc)
    guard IConv.encodingsList.contains(fin) else { throw SAXError.UnsupportedCharacterEncoding(1, 1, description: "Unsupported Character Encoding: \(fin)") }
    return fin
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
        case UTF_32, UTF_32BE, UTF_32LE: return (xmlDeclEncoding.hasPrefix(UTF_32) ? guessedEncoding : xmlDeclEncoding);
        case UTF_16, UTF_16BE, UTF_16LE: return (xmlDeclEncoding.hasPrefix(UTF_16) ? guessedEncoding : xmlDeclEncoding);
        default: return xmlDeclEncoding
    }
}
