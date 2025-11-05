import Foundation
import Testing

@Suite("Basic Tests")
struct BasicTests {
    @Test("Simple math test")
    func simpleMath() {
        #expect(2 + 2 == 4)
    }

    @Test("String test")
    func stringTest() {
        #expect("hello".uppercased() == "HELLO")
    }
}
