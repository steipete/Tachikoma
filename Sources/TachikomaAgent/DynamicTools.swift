import Foundation
import Tachikoma

public struct ToolParameter: Sendable {
    public let name: String
    public let type: DynamicSchema.SchemaType
    public let description: String
    public let required: Bool

    public init(name: String, type: DynamicSchema.SchemaType, description: String, required: Bool) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
    }
}

// MARK: - Dynamic Tool System Extensions

// Core dynamic tool types (DynamicToolProvider, DynamicTool, DynamicSchema) are now in Core/ToolTypes.swift
// This file contains additional dynamic tool functionality and extensions

private struct DynamicToolProviderSource: Sendable {
    let id: String
    let registrationID: UUID?
    let provider: DynamicToolProvider
}

private struct ResolvedDynamicTool: Sendable {
    let sourceID: String
    let registrationID: UUID?
    let registryGeneration: UUID?
    let provider: DynamicToolProvider
    let tool: DynamicTool

    func issued(in registryGeneration: UUID) -> ResolvedDynamicTool {
        ResolvedDynamicTool(
            sourceID: self.sourceID,
            registrationID: self.registrationID,
            registryGeneration: registryGeneration,
            provider: self.provider,
            tool: self.tool,
        )
    }
}

private struct DynamicToolBindingIdentity: Sendable, Equatable {
    let sourceID: String
    let registrationID: UUID?
}

private enum DynamicToolBindingLookup: Sendable {
    case uninitialized
    case missing
    case invalidated
    case bound(ResolvedDynamicTool)
}

private actor DynamicToolBindingStore {
    private var bindings: [String: ResolvedDynamicTool]?
    private var bindingPlan: [String: DynamicToolBindingIdentity]?
    private var invalidatedNames: Set<String> = []

    func apply(_ resolvedTools: [ResolvedDynamicTool]) -> [String] {
        let nextBindings = Dictionary(uniqueKeysWithValues: resolvedTools.map { ($0.tool.name, $0) })
        let nextPlan = nextBindings.mapValues { binding in
            DynamicToolBindingIdentity(
                sourceID: binding.sourceID,
                registrationID: binding.registrationID,
            )
        }
        if let bindingPlan = self.bindingPlan {
            for (name, previous) in bindingPlan {
                guard let next = nextPlan[name], next == previous else {
                    self.invalidatedNames.insert(name)
                    continue
                }
            }
        }

        let blockedNames = nextBindings.keys.filter { self.invalidatedNames.contains($0) }.sorted()
        guard blockedNames.isEmpty else {
            self.bindings = nil
            return blockedNames
        }

        self.bindingPlan = nextPlan
        self.bindings = nextBindings
        return []
    }

    func lookup(name: String) -> DynamicToolBindingLookup {
        if self.invalidatedNames.contains(name) {
            return .invalidated
        }
        guard let bindings = self.bindings else {
            return .uninitialized
        }
        guard let binding = bindings[name] else {
            return .missing
        }
        return .bound(binding)
    }

    func suspend() {
        self.bindings = nil
    }
}

private enum DynamicToolResolver {
    static func resolve(_ sources: [DynamicToolProviderSource]) async throws -> [ResolvedDynamicTool] {
        var resolved: [ResolvedDynamicTool] = []

        for source in sources {
            let tools = try await source.provider.discoverTools()
            resolved.append(contentsOf: tools.map { tool in
                ResolvedDynamicTool(
                    sourceID: source.id,
                    registrationID: source.registrationID,
                    registryGeneration: nil,
                    provider: source.provider,
                    tool: tool,
                )
            })
        }

        let duplicateGroups = Dictionary(grouping: resolved, by: \.tool.name)
            .filter { $0.value.count > 1 }
        guard duplicateGroups.isEmpty else {
            let conflicts = duplicateGroups.keys.sorted().map { name in
                let sources = duplicateGroups[name, default: []]
                    .map(\.sourceID)
                    .sorted()
                    .joined(separator: ", ")
                return "\(name) [\(sources)]"
            }.joined(separator: "; ")
            throw TachikomaError.toolCallFailed("Ambiguous dynamic tool names: \(conflicts)")
        }

        return resolved
    }
}

// MARK: - Dynamic Tool Registry

/// Registry for managing dynamic tool providers
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor DynamicToolRegistry {
    private struct RegisteredProvider: Sendable {
        let registrationID: UUID
        let provider: DynamicToolProvider
    }

    private var providers: [String: RegisteredProvider] = [:]
    private var bindingGeneration = UUID()
    private var bindingPlan: [String: DynamicToolBindingIdentity]?

    public init() {}

    /// Register a dynamic tool provider
    public func register(_ provider: DynamicToolProvider, id: String) {
        self.providers[id] = RegisteredProvider(registrationID: UUID(), provider: provider)
        self.invalidateBindings()
    }

    /// Unregister a provider
    public func unregister(id: String) {
        if self.providers.removeValue(forKey: id) != nil {
            self.invalidateBindings()
        }
    }

    /// Get all registered providers
    public var allProviders: [DynamicToolProvider] {
        self.providers.sorted { $0.key < $1.key }.map(\.value.provider)
    }

    /// Discover all tools from all providers
    public func discoverAllTools() async throws -> [DynamicTool] {
        try await self.resolveTools().map(\.tool)
    }

    /// Convert all discovered tools to AgentTools
    public func getAllAgentTools() async throws -> [AgentTool] {
        let resolvedTools = try await self.resolveTools()

        return resolvedTools.map { resolved in
            resolved.tool.toAgentTool { arguments in
                try await self.execute(resolved, arguments: arguments)
            }
        }
    }

    private func resolveTools() async throws -> [ResolvedDynamicTool] {
        let observedGeneration = self.bindingGeneration
        let sources = self.providers.sorted { $0.key < $1.key }.map { id, registration in
            DynamicToolProviderSource(
                id: id,
                registrationID: registration.registrationID,
                provider: registration.provider,
            )
        }

        do {
            let resolvedTools = try await DynamicToolResolver.resolve(sources)
            guard self.bindingGeneration == observedGeneration else {
                throw TachikomaError.toolCallFailed("Dynamic tool registry changed during discovery")
            }

            let nextPlan = Dictionary(uniqueKeysWithValues: resolvedTools.map { resolved in
                (
                    resolved.tool.name,
                    DynamicToolBindingIdentity(
                        sourceID: resolved.sourceID,
                        registrationID: resolved.registrationID,
                    ),
                )
            })
            if let bindingPlan = self.bindingPlan, bindingPlan != nextPlan {
                self.bindingGeneration = UUID()
            }
            self.bindingPlan = nextPlan
            let issuedGeneration = self.bindingGeneration
            return resolvedTools.map { $0.issued(in: issuedGeneration) }
        } catch {
            if self.bindingGeneration == observedGeneration {
                self.invalidateBindings()
            }
            throw error
        }
    }

    private func execute(
        _ resolved: ResolvedDynamicTool,
        arguments: AgentToolArguments,
    ) async throws
        -> AnyAgentToolValue
    {
        guard
            let registrationID = resolved.registrationID,
            let registryGeneration = resolved.registryGeneration,
            let current = self.providers[resolved.sourceID],
            current.registrationID == registrationID,
            self.bindingGeneration == registryGeneration else
        {
            throw TachikomaError.toolCallFailed(
                "Provider registration changed for tool: \(resolved.tool.name)",
            )
        }

        return try await current.provider.executeTool(name: resolved.tool.name, arguments: arguments)
    }

    private func invalidateBindings() {
        self.bindingGeneration = UUID()
        self.bindingPlan = nil
    }
}

// MARK: - Mock Dynamic Tool Provider

/// Mock provider for testing dynamic tools
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct MockDynamicToolProvider: DynamicToolProvider {
    private let tools: [DynamicTool]
    private let executor: @Sendable (String, AgentToolArguments) async throws -> AnyAgentToolValue

    public init(
        tools: [DynamicTool],
        executor: @escaping @Sendable (String, AgentToolArguments) async throws -> AnyAgentToolValue = { name, _ in
            AnyAgentToolValue(string: "Mock result for \(name)")
        },
    ) {
        self.tools = tools
        self.executor = executor
    }

    public func discoverTools() async throws -> [DynamicTool] {
        self.tools
    }

    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        guard self.tools.contains(where: { $0.name == name }) else {
            throw TachikomaError.toolCallFailed("Tool not found: \(name)")
        }
        return try await self.executor(name, arguments)
    }
}

// MARK: - Dynamic Tool Builders

/// Builder for creating dynamic tools programmatically
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct DynamicToolBuilder {
    /// Create a simple string-input, string-output tool
    public static func simpleStringTool(
        name: String,
        description: String,
        parameterName: String = "input",
        parameterDescription: String = "Input string",
    )
        -> DynamicTool
    {
        // Create a simple string-input, string-output tool
        DynamicTool(
            name: name,
            description: description,
            schema: DynamicSchema(
                type: .object,
                properties: [
                    parameterName: DynamicSchema.SchemaProperty(
                        type: .string,
                        description: parameterDescription,
                    ),
                ],
                required: [parameterName],
            ),
        )
    }

    /// Create a tool with multiple parameters
    public static func multiParameterTool(
        name: String,
        description: String,
        parameters: [ToolParameter],
    )
        -> DynamicTool
    {
        // Create a tool with multiple parameters
        var properties: [String: DynamicSchema.SchemaProperty] = [:]
        var required: [String] = []

        for param in parameters {
            properties[param.name] = DynamicSchema.SchemaProperty(
                type: param.type,
                description: param.description,
            )
            if param.required {
                required.append(param.name)
            }
        }

        return DynamicTool(
            name: name,
            description: description,
            schema: DynamicSchema(
                type: .object,
                properties: properties,
                required: required,
            ),
        )
    }
}

// MARK: - Dynamic Schema Extensions

extension DynamicSchema.SchemaProperty {
    /// Create a string property with constraints
    public static func string(
        description: String,
        enumValues: [String]? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        format: String? = nil,
    )
        -> Self
    {
        // Create a string property with constraints
        Self(
            type: .string,
            description: description,
            enumValues: enumValues,
            format: format,
            minLength: minLength,
            maxLength: maxLength,
        )
    }

    /// Create a number property with constraints
    public static func number(
        description: String,
        minimum: Double? = nil,
        maximum: Double? = nil,
    )
        -> Self
    {
        // Create a number property with constraints
        Self(
            type: .number,
            description: description,
            minimum: minimum,
            maximum: maximum,
        )
    }

    /// Create an array property
    public static func array(
        description: String,
        items: DynamicSchema.SchemaItems,
    )
        -> Self
    {
        // Create an array property
        Self(
            type: .array,
            description: description,
            items: items,
        )
    }

    /// Create an object property
    public static func object(
        description: String,
        properties: [String: DynamicSchema.SchemaProperty]? = nil,
        required: [String]? = nil,
    )
        -> Self
    {
        // Create an object property
        Self(
            type: .object,
            description: description,
            properties: properties,
            required: required,
        )
    }
}

// MARK: - Composite Dynamic Tool Provider

/// Combines multiple dynamic tool providers into one
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CompositeDynamicToolProvider: DynamicToolProvider {
    private let providers: [DynamicToolProvider]
    private let bindingStore: DynamicToolBindingStore

    public init(providers: [DynamicToolProvider]) {
        self.providers = providers
        self.bindingStore = DynamicToolBindingStore()
    }

    public func discoverTools() async throws -> [DynamicTool] {
        try await self.discoverAndBind().map(\.tool)
    }

    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        let resolved = try await self.resolvedTool(named: name)
        return try await resolved.provider.executeTool(name: name, arguments: arguments)
    }

    private func discoverAndBind() async throws -> [ResolvedDynamicTool] {
        do {
            let resolvedTools = try await self.resolveTools()
            let invalidatedNames = await self.bindingStore.apply(resolvedTools)
            guard invalidatedNames.isEmpty else {
                throw TachikomaError.toolCallFailed(
                    "Composite dynamic tool bindings changed: \(invalidatedNames.joined(separator: ", "))",
                )
            }
            return resolvedTools
        } catch {
            await self.bindingStore.suspend()
            throw error
        }
    }

    private func resolvedTool(named name: String) async throws -> ResolvedDynamicTool {
        switch await self.bindingStore.lookup(name: name) {
        case .uninitialized:
            _ = try await self.discoverAndBind()
            return try await self.resolvedTool(named: name)
        case .missing:
            throw TachikomaError.toolCallFailed("Tool not found in any provider: \(name)")
        case .invalidated:
            throw TachikomaError.toolCallFailed("Composite dynamic tool binding changed: \(name)")
        case let .bound(resolved):
            return resolved
        }
    }

    private func resolveTools() async throws -> [ResolvedDynamicTool] {
        let sources = self.providers.enumerated().map { index, provider in
            DynamicToolProviderSource(
                id: "provider[\(index)]",
                registrationID: nil,
                provider: provider,
            )
        }
        return try await DynamicToolResolver.resolve(sources)
    }
}

// MARK: - Filtering Dynamic Tool Provider

/// Wraps a provider and filters its tools based on criteria
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct FilteringDynamicToolProvider: DynamicToolProvider {
    private let baseProvider: DynamicToolProvider
    private let filter: @Sendable (DynamicTool) -> Bool

    public init(
        baseProvider: DynamicToolProvider,
        filter: @escaping @Sendable (DynamicTool) -> Bool,
    ) {
        self.baseProvider = baseProvider
        self.filter = filter
    }

    public func discoverTools() async throws -> [DynamicTool] {
        let allTools = try await baseProvider.discoverTools()
        return allTools.filter(self.filter)
    }

    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // Check if the tool passes the filter
        let tools = try await discoverTools()
        guard tools.contains(where: { $0.name == name }) else {
            throw TachikomaError.toolCallFailed("Tool filtered out or not found: \(name)")
        }

        return try await self.baseProvider.executeTool(name: name, arguments: arguments)
    }
}

// MARK: - Caching Dynamic Tool Provider

/// Wraps a provider and caches tool discovery results
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor CachingDynamicToolProvider: DynamicToolProvider {
    private let baseProvider: DynamicToolProvider
    private var cachedTools: [DynamicTool]?
    private let cacheDuration: TimeInterval
    private var lastCacheTime: Date?

    public init(
        baseProvider: DynamicToolProvider,
        cacheDuration: TimeInterval = 60, // 1 minute default
    ) {
        self.baseProvider = baseProvider
        self.cacheDuration = cacheDuration
    }

    public func discoverTools() async throws -> [DynamicTool] {
        // Check if cache is valid
        if
            let cachedTools,
            let lastCacheTime,
            Date().timeIntervalSince(lastCacheTime) < cacheDuration
        {
            return cachedTools
        }

        // Refresh cache
        let tools = try await baseProvider.discoverTools()
        cachedTools = tools
        lastCacheTime = Date()
        return tools
    }

    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // Ensure the tool exists in our cache
        let tools = try await discoverTools()
        guard tools.contains(where: { $0.name == name }) else {
            throw TachikomaError.toolCallFailed("Tool not found: \(name)")
        }

        return try await self.baseProvider.executeTool(name: name, arguments: arguments)
    }

    /// Clear the cache
    public func clearCache() {
        // Clear the cache
        self.cachedTools = nil
        self.lastCacheTime = nil
    }
}
