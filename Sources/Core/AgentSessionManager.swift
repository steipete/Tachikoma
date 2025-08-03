<<<<<<< HEAD
import Foundation

// MARK: - Agent Session

/// Represents a persistent agent conversation session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentSession: Codable, Sendable {
    /// Unique session identifier
    public let id: String
    
    /// Messages in the conversation
    public let messages: [Message]
    
    /// Session metadata
    public let metadata: SessionMetadata?
    
    /// When the session was created
    public let createdAt: Date
    
    /// When the session was last updated
    public let updatedAt: Date
    
    /// Number of messages in the session
    public var messageCount: Int {
        messages.count
    }
    
    public init(
        id: String,
        messages: [Message],
        metadata: SessionMetadata? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.messages = messages
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Session Metadata

/// Metadata associated with an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionMetadata: Codable, Sendable {
    /// Agent name that created the session
    public let agentName: String?
    
    /// Model used in the session
    public let modelName: String?
    
    /// Total tokens used in the session
    public let totalTokens: Int?
    
    /// Session tags for organization
    public let tags: [String]?
    
    /// Custom metadata
    public let customData: [String: String]?
    
    public init(
        agentName: String? = nil,
        modelName: String? = nil,
        totalTokens: Int? = nil,
        tags: [String]? = nil,
        customData: [String: String]? = nil
    ) {
        self.agentName = agentName
        self.modelName = modelName
        self.totalTokens = totalTokens
        self.tags = tags
        self.customData = customData
    }
}

// MARK: - Session Summary

/// Summary information about a session for listing
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionSummary: Sendable {
    /// Session ID
    public let id: String
    
    /// Creation date
    public let createdAt: Date
    
    /// Last update date
    public let updatedAt: Date
    
    /// Number of messages
    public let messageCount: Int
    
    /// Agent name if available
    public let agentName: String?
    
    /// Model name if available
    public let modelName: String?
    
    public init(
        id: String,
        createdAt: Date,
        updatedAt: Date,
        messageCount: Int,
        agentName: String? = nil,
        modelName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.agentName = agentName
        self.modelName = modelName
    }
}

// MARK: - Agent Session Manager

/// Manages agent conversation sessions for persistence and resume functionality
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public actor AgentSessionManager {
    private let sessionDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Session cache to avoid repeated disk reads
    private var sessionCache: [String: AgentSession] = [:]

    public init(directory: URL? = nil) {
        // Configure JSON encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Default to ~/.tachikoma/sessions/
        if let directory {
            self.sessionDirectory = directory
        } else {
            let homeDirectory = fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDirectory
                .appendingPathComponent(".tachikoma")
                .appendingPathComponent("sessions")
        }

        // Ensure directory exists
        try? fileManager.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Public Methods

    /// Save a session
    public func saveSession(
        id: String,
        messages: [Message],
        metadata: SessionMetadata? = nil
    ) throws {
        let session = AgentSession(
            id: id,
            messages: messages,
            metadata: metadata,
            createdAt: sessionCache[id]?.createdAt ?? Date(),
            updatedAt: Date()
        )

        // Update cache
        sessionCache[id] = session

        // Save to disk
        let url = sessionURL(for: id)
        let data = try encoder.encode(session)
        try data.write(to: url)
    }

    /// Load a session
    public func loadSession(id: String) throws -> AgentSession? {
        // Check cache first
        if let cached = sessionCache[id] {
            return cached
        }

        // Load from disk
        let url = sessionURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let session = try decoder.decode(AgentSession.self, from: data)

        // Update cache
        sessionCache[id] = session

        return session
    }

    /// Delete a session
    public func deleteSession(id: String) throws {
        // Remove from cache
        sessionCache.removeValue(forKey: id)

        // Remove from disk
        let url = sessionURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// List all sessions
    public func listSessions() throws -> [SessionSummary] {
        let contents = try fileManager.contentsOfDirectory(
            at: sessionDirectory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let sessionFiles = contents.filter { $0.pathExtension == "json" }
        
        return sessionFiles.compactMap { url in
            let sessionId = url.deletingPathExtension().lastPathComponent
            
            // Try to load from cache first
            if let cached = sessionCache[sessionId] {
                return SessionSummary(
                    id: cached.id,
                    createdAt: cached.createdAt,
                    updatedAt: cached.updatedAt,
                    messageCount: cached.messageCount,
                    agentName: cached.metadata?.agentName,
                    modelName: cached.metadata?.modelName
                )
            }
            
            // Load minimal data from disk if not cached
            guard let data = try? Data(contentsOf: url),
                  let session = try? decoder.decode(AgentSession.self, from: data) else {
                return nil
            }
            
            return SessionSummary(
                id: session.id,
                createdAt: session.createdAt,
                updatedAt: session.updatedAt,
                messageCount: session.messageCount,
                agentName: session.metadata?.agentName,
                modelName: session.metadata?.modelName
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Clear all sessions
    public func clearAllSessions() throws {
        sessionCache.removeAll()
        
        let contents = try fileManager.contentsOfDirectory(
            at: sessionDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        for url in contents where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }

    /// Get session count
    public func sessionCount() throws -> Int {
        let contents = try fileManager.contentsOfDirectory(
            at: sessionDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        return contents.filter { $0.pathExtension == "json" }.count
    }

    // MARK: - Private Methods

    private func sessionURL(for id: String) -> URL {
        return sessionDirectory.appendingPathComponent("\(id).json")
    }
}
||||||| parent of 69989a9 (fix: Update test suite to match current API)
=======
import Foundation

/// Summary information about an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionSummary: Sendable, Codable {
    /// Unique session identifier
    public let id: String

    /// Model name used in this session
    public let modelName: String

    /// When the session was created
    public let createdAt: Date

    /// When the session was last accessed
    public let lastAccessedAt: Date

    /// Number of messages in the session
    public let messageCount: Int

    /// Session status
    public let status: SessionStatus

    /// Brief description of the session
    public let summary: String?

    public init(
        id: String,
        modelName: String,
        createdAt: Date,
        lastAccessedAt: Date,
        messageCount: Int,
        status: SessionStatus,
        summary: String? = nil
    ) {
        self.id = id
        self.modelName = modelName
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.messageCount = messageCount
        self.status = status
        self.summary = summary
    }
}

/// Status of an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case failed
    case expired
}

/// Complete agent session with full conversation history
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentSession: Sendable, Codable {
    /// Unique session identifier
    public let id: String

    /// Model name used in this session
    public let modelName: String

    /// Complete conversation history
    public let messages: [Message]

    /// Session metadata
    public let metadata: SessionMetadata

    /// When the session was created
    public let createdAt: Date

    /// When the session was last updated
    public let updatedAt: Date

    public init(
        id: String,
        modelName: String,
        messages: [Message],
        metadata: SessionMetadata,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.modelName = modelName
        self.messages = messages
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Metadata associated with an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionMetadata: Sendable, Codable {
    /// Total tokens used across all requests
    public let totalTokens: Int

    /// Total cost if available
    public let totalCost: Double?

    /// Number of tool calls made
    public let toolCallCount: Int

    /// Total execution time in seconds
    public let totalExecutionTime: TimeInterval

    /// Additional custom metadata
    public let customData: [String: String]

    public init(
        totalTokens: Int = 0,
        totalCost: Double? = nil,
        toolCallCount: Int = 0,
        totalExecutionTime: TimeInterval = 0,
        customData: [String: String] = [:]
    ) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.toolCallCount = toolCallCount
        self.totalExecutionTime = totalExecutionTime
        self.customData = customData
    }
}

/// Manages agent conversation sessions with persistence and caching
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AgentSessionManager: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let sessionDirectory: URL
    private var sessionCache: [String: AgentSession] = [:]
    private let cacheQueue = DispatchQueue(label: "tachikoma.session.cache", attributes: .concurrent)

    /// Maximum number of sessions to keep in memory cache
    public static let maxCacheSize = 50

    /// Maximum age for sessions before they're considered expired
    public static let maxSessionAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    public init(sessionDirectory: URL? = nil) throws {
        if let sessionDirectory {
            self.sessionDirectory = sessionDirectory
        } else {
            // Default to ~/.tachikoma/sessions/
            let homeDir = fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDir.appendingPathComponent(".tachikoma/sessions")
        }

        // Create session directory if it doesn't exist
        try fileManager.createDirectory(at: self.sessionDirectory, withIntermediateDirectories: true)
    }

    /// List all available sessions
    public func listSessions() -> [SessionSummary] {
        do {
            let sessionFiles = try fileManager.contentsOfDirectory(
                at: sessionDirectory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]
            )

            return sessionFiles.compactMap { url in
                guard url.pathExtension == "json" else { return nil }

                do {
                    let data = try Data(contentsOf: url)
                    let session = try JSONDecoder().decode(AgentSession.self, from: data)

                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let createdAt = resourceValues.creationDate ?? Date()
                    let lastAccessedAt = resourceValues.contentModificationDate ?? Date()

                    return SessionSummary(
                        id: session.id,
                        modelName: session.modelName,
                        createdAt: createdAt,
                        lastAccessedAt: lastAccessedAt,
                        messageCount: session.messages.count,
                        status: isSessionExpired(lastAccessedAt) ? .expired : .active,
                        summary: generateSessionSummary(from: session.messages)
                    )
                } catch {
                    return nil
                }
            }.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
        } catch {
            return []
        }
    }

    /// Save a session to persistent storage
    public func saveSession(_ session: AgentSession) throws {
        let sessionFile = sessionDirectory.appendingPathComponent("\(session.id).json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionFile)

        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[session.id] = session
            self.evictOldCacheEntries()
        }
    }

    /// Load a session from storage
    public func loadSession(id: String) throws -> AgentSession? {
        // Check cache first
        let cachedSession = cacheQueue.sync {
            sessionCache[id]
        }

        if let cachedSession {
            return cachedSession
        }

        // Load from disk
        let sessionFile = sessionDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: sessionFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: sessionFile)
        let session = try JSONDecoder().decode(AgentSession.self, from: data)

        // Add to cache
        cacheQueue.async(flags: .barrier) {
            self.sessionCache[id] = session
            self.evictOldCacheEntries()
        }

        return session
    }

    /// Delete a session
    public func deleteSession(id: String) throws {
        let sessionFile = sessionDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: sessionFile)

        // Remove from cache
        cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeValue(forKey: id)
        }
    }

    /// Clean up expired sessions
    public func cleanupExpiredSessions() throws {
        let sessions = listSessions()
        let expiredSessions = sessions.filter { isSessionExpired($0.lastAccessedAt) }

        for session in expiredSessions {
            try deleteSession(id: session.id)
        }
    }

    // MARK: - Private Methods

    private func isSessionExpired(_ lastAccessed: Date) -> Bool {
        Date().timeIntervalSince(lastAccessed) > Self.maxSessionAge
    }

    private func generateSessionSummary(from messages: [Message]) -> String? {
        // Find the first user message to use as summary
        for message in messages {
            if case let .user(_, content) = message {
                switch content {
                case let .text(text):
                    return String(text.prefix(100))
                case let .multimodal(parts):
                    for part in parts {
                        if let text = part.text {
                            return String(text.prefix(100))
                        }
                    }
                case .image, .file, .audio:
                    continue // Skip non-text content
                }
            }
        }
        return nil
    }

    private func evictOldCacheEntries() {
        guard sessionCache.count > Self.maxCacheSize else { return }

        // Remove oldest entries
        let sortedKeys = sessionCache.keys.sorted { key1, key2 in
            let session1 = sessionCache[key1]!
            let session2 = sessionCache[key2]!
            return session1.updatedAt < session2.updatedAt
        }

        let keysToRemove = sortedKeys.prefix(sessionCache.count - Self.maxCacheSize)
        for key in keysToRemove {
            sessionCache.removeValue(forKey: key)
        }
    }
}
>>>>>>> 69989a9 (fix: Update test suite to match current API)
