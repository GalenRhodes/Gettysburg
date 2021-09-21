/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Enums.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation

public enum LeadingWhitespace: String, Codable {
    case None
    case Allowed
    case Required
}

public enum SuffixOption: Codable {
    /*===========================================================================================================================*/
    /// Return the characters but leave them on the input stream.
    ///
    case Peek(count: Int)
    /*===========================================================================================================================*/
    /// Return the characters and remove them from the input stream.
    ///
    case Keep
    /*===========================================================================================================================*/
    /// Do not return the characters and leave them on the input stream.
    ///
    case Leave(count: Int)
    /*===========================================================================================================================*/
    /// Do not return the characters but remove them from the input stream
    ///
    case Drop(count: Int)

    private enum CodingKeys: String, CodingKey { case name, count }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        switch name {
            case "Peek":  self = .Peek(count: try container.decode(Int.self, forKey: .count))
            case "Leave": self = .Leave(count: try container.decode(Int.self, forKey: .count))
            case "Drop":  self = .Drop(count: try container.decode(Int.self, forKey: .count))
            default:      self = .Keep
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .Peek(count: let cc):
                try container.encode("Peek", forKey: .name)
                try container.encode(cc, forKey: .count)
            case .Keep:
                try container.encode("Keep", forKey: .name)
            case .Leave(count: let cc):
                try container.encode("Leave", forKey: .name)
                try container.encode(cc, forKey: .count)
            case .Drop(count: let cc):
                try container.encode("Drop", forKey: .name)
                try container.encode(cc, forKey: .count)
        }
    }
}
