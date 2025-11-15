import Foundation

extension String {
    /// Convert the string to UTF-8 encoded `Data`.
    public func utf8Data() -> Data {
        Data(utf8)
    }
}
