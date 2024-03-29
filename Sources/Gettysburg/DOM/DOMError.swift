/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: DOMError.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 10/18/21
 *
 * Copyright © 2021. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *===============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

public class DOMError: Error, Codable, CustomStringConvertible {
    private enum CodingKeys: String, CodingKey { case description }

    public let description: String

    public init(description: String) {
        self.description = description
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decode(String.self, forKey: .description)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
    }

    //@f:0
    public final class NodeNotFound: DOMError {
        public override init(description: String) { super.init(description: description) }
        public required init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }

    public final class ReadOnly: DOMError {
        public override init(description: String) { super.init(description: description) }
        public required init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }

    public final class WrongDocument: DOMError {
        public override init(description: String) { super.init(description: description) }
        public required init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }

    public final class Hierarchy: DOMError {
        public override init(description: String) { super.init(description: description) }
        public required init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }
}
