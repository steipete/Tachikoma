import Foundation

actor TestEnvironmentMutex {
    static let shared = TestEnvironmentMutex()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func lock() async {
        if !self.isLocked {
            self.isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            self.waiters.append(continuation)
        }
    }

    private func unlock() {
        if self.waiters.isEmpty {
            self.isLocked = false
            return
        }

        let next = self.waiters.removeFirst()
        next.resume()
    }

    func withLock<T: Sendable>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        await self.lock()
        defer { self.unlock() }
        return try await body()
    }
}
