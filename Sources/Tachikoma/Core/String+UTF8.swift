//
//  String+UTF8.swift
//  Tachikoma
//

import Foundation

public extension String {
    /// Convert the string to UTF-8 encoded `Data`.
    func utf8Data() -> Data {
        Data(self.utf8)
    }
}
