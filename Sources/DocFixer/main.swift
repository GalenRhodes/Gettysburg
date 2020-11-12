//
//  main.swift
//  DocFixer
//
//  Created by Galen Rhodes on 3/26/20.
//  Copyright © 2020 Project Galen. All rights reserved.
//

import Foundation
import PGDocFixer

func docFixer() -> Int {
    let mAndR: [RegexRepl] = [
        RegexRepl(pattern: "(?<!\\w|`)(nil)(?!\\w|`)", repl: "`$1`"),
        RegexRepl(pattern: "(?<!\\w|`)(\\w+(?:\\.\\w+)*\\([^)]*\\))(?!\\w|`)", repl: "`$1`"),
    ]
    return doDocFixer(args: CommandLine.arguments, replacements: mAndR)
}

exit(Int32(docFixer()))
