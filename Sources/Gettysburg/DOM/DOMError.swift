/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: SimpleIConvCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/12/21
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

public enum DOMError: Error, Codable {
    private enum CodingKeys: String, CodingKey { case type, description }

    case NoModificationAllowed(description: String = "No Modification Allowed")
    case WrongDocument(description: String = "Wrong Document")
    case HierarchyViolation(description: String = "Hierarchy Violation")
    case NotSupported(description: String = "Operation Not Supported")

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let n = try c.decode(String.self, forKey: .type)
        switch n {
            case "NoModificationAllowed": self = .NoModificationAllowed(description: try c.decode(String.self, forKey: .description))
            case "WrongDocument":         self = .WrongDocument(description: try c.decode(String.self, forKey: .description))
            case "HierarchyViolation":    self = .HierarchyViolation(description: try c.decode(String.self, forKey: .description))
            case "NotSupported":          self = .NotSupported(description: try c.decode(String.self, forKey: .description))
            default: fatalError("Unknown DOMError type.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .NoModificationAllowed(description: let description):
                try c.encode("NoModificationAllowed", forKey: .type)
                try c.encode(description, forKey: .description)
            case .WrongDocument(description: let description):
                try c.encode("WrongDocument", forKey: .type)
                try c.encode(description, forKey: .description)
            case .HierarchyViolation(description: let description):
                try c.encode("HierarchyViolation", forKey: .type)
                try c.encode(description, forKey: .description)
            case .NotSupported(description: let description):
                try c.encode("NotSupported", forKey: .type)
                try c.encode(description, forKey: .description)
        }
    }
}
