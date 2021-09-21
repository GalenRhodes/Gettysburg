/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: CodableTests.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: August 13, 2021
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

class Root: Codable {
    enum CodingKeys: String, CodingKey { case className, string1, number1, number2, list }

    let string1: String

    init(str1: String) { string1 = str1 }

    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(from: c)
    }

    init(from c: KeyedDecodingContainer<CodingKeys>) throws {
        string1 = try c.decode(String.self, forKey: .string1)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try encode(to: &c)
    }

    func encode(to c: inout KeyedEncodingContainer<CodingKeys>) throws {
        try c.encode(String(describing: type(of: self)), forKey: .className)
        try c.encode(string1, forKey: .string1)
    }
}

class Child1: Root {
    let number1: Int

    init(str1: String, num1: Int) {
        number1 = num1
        super.init(str1: str1)
    }

    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(from: c)
    }

    override init(from c: KeyedDecodingContainer<CodingKeys>) throws {
        number1 = try c.decode(Int.self, forKey: .number1)
        try super.init(from: c)
    }

    override func encode(to c: inout KeyedEncodingContainer<Root.CodingKeys>) throws {
        try super.encode(to: &c)
        try c.encode(number1, forKey: .number1)
    }
}

class Child2: Root {
    let number2: Double

    init(str1: String, num2: Double) {
        number2 = num2
        super.init(str1: str1)
    }

    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(from: c)
    }

    override init(from c: KeyedDecodingContainer<CodingKeys>) throws {
        number2 = try c.decode(Double.self, forKey: .number2)
        try super.init(from: c)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(number2, forKey: .number2)
    }
}

class Child3: Root {
    var list: [Root] = []

    override init(str1: String) {
        super.init(str1: str1)
    }

    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(from: c)
    }

    override init(from c: KeyedDecodingContainer<CodingKeys>) throws {
        var l = try c.nestedUnkeyedContainer(forKey: .list)
        while !l.isAtEnd {
            let cc = try l.nestedContainer(keyedBy: CodingKeys.self)
            let cn = try cc.decode(String.self, forKey: .className)
            switch cn {
                case "Child1": list.append(try Child1(from: cc))
                case "Child2": list.append(try Child2(from: cc))
                case "Child3": list.append(try Child3(from: cc))
                default: list.append(try Root(from: cc))
            }
        }
        try super.init(from: c)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(list, forKey: .list)
    }
}

let obj: Child3 = Child3(str1: "Galen")
obj.list.append(Child2(str1: "Michelle", num2: 1.0))
obj.list.append(Child1(str1: "Jason", num1: 2))
obj.list.append(Child1(str1: "Collin", num1: 1))
obj.list.append(Root(str1: "Jimmy"))

let enc = JSONEncoder()
enc.outputFormatting = [ .prettyPrinted, .sortedKeys ]
let data = try enc.encode(obj)
let str  = String(data: data, encoding: .utf8) ?? "-nil-"
print(str)

let dec   = JSONDecoder()
let obj2  = try dec.decode(Child3.self, from: data)
let data2 = try enc.encode(obj2)
let str2  = String(data: data, encoding: .utf8) ?? "-nil-"
print(str2)
