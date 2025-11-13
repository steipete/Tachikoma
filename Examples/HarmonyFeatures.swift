#!/usr/bin/env swift

import Foundation
import Tachikoma

// MARK: - Multi-Channel Response Example

func demonstrateMultiChannelResponse() async throws {
    print("=== Multi-Channel Response Demo ===\n")

    let result = try await generateText(
        model: .openai(.gpt4o),
        messages: [
            .user("Explain how recursion works in programming"),
        ],
        settings: GenerationSettings(
            reasoningEffort: .medium,
        ),
    )

    // Process messages by channel
    for message in result.messages {
        if let channel = message.channel {
            print("[\(channel)] \(message.content.first?.textValue ?? "")")
        } else {
            print(message.content.first?.textValue ?? "")
        }
    }
}

// MARK: - Reasoning Effort Example

func demonstrateReasoningEffort() async throws {
    print("\n=== Reasoning Effort Demo ===\n")

    // High effort for complex problem
    print("High effort response:")
    let complexResult = try await generateText(
        model: .openai(.gpt4o),
        messages: [
            .user("Design a distributed system for real-time collaboration"),
        ],
        settings: GenerationSettings(
            reasoningEffort: .high,
            maxTokens: 2000,
        ),
    )
    print("Tokens used: \(complexResult.usage?.totalTokens ?? 0)")

    // Low effort for simple query
    print("\nLow effort response:")
    let simpleResult = try await generateText(
        model: .openai(.gpt4o),
        messages: [
            .user("What is the capital of Japan?"),
        ],
        settings: GenerationSettings(
            reasoningEffort: .low,
        ),
    )
    print("Tokens used: \(simpleResult.usage?.totalTokens ?? 0)")
}

// MARK: - Retry Handler Example

func demonstrateRetryHandler() async throws {
    print("\n=== Retry Handler Demo ===\n")

    let retryHandler = RetryHandler(
        policy: RetryPolicy(
            maxAttempts: 3,
            baseDelay: 1.0,
        ) { error in
            print("Checking if should retry for: \(error)")
            return true // Always retry for demo
        },
    )

    do {
        let response = try await retryHandler.execute(
            operation: {
                print("Attempting API call...")
                // Simulate a call that might fail
                return try await generateText(
                    model: .openai(.gpt4o),
                    messages: [.user("Hello")],
                )
            },
            onRetry: { attempt, delay, error in
                print("Retry attempt \(attempt) after \(delay)s due to: \(error)")
            },
        )
        print("Success: \(response.text)")
    } catch {
        print("Failed after retries: \(error)")
    }
}

// MARK: - Enhanced Tools Example

func demonstrateEnhancedTools() async throws {
    print("\n=== Enhanced Tools Demo ===\n")

    // Create tools with namespaces
    let calculatorTool = AgentTool(
        name: "calculate",
        description: "Perform mathematical calculations",
        parameters: AgentToolParameters(
            properties: [
                AgentToolParameterProperty(
                    name: "expression",
                    type: .string,
                    description: "Mathematical expression to evaluate",
                ),
            ],
            required: ["expression"],
        ),
        namespace: "math",
        recipient: "calculator-service",
    ) { args in
        let expr = args["expression"]?.stringValue ?? "0"
        // Simple demo: just return 42
        return .double(42.0)
    }

    let weatherTool = AgentTool(
        name: "getWeather",
        description: "Get current weather",
        parameters: AgentToolParameters(
            properties: [
                AgentToolParameterProperty(
                    name: "location",
                    type: .string,
                    description: "City name",
                ),
            ],
            required: ["location"],
        ),
        namespace: "weather",
        recipient: "weather-api",
    ) { args in
        let location = args["location"]?.stringValue ?? "Unknown"
        return .string("Sunny, 72°F in \(location)")
    }

    let result = try await generateText(
        model: .openai(.gpt4o),
        messages: [
            .user("What's 25 * 4 and what's the weather in Tokyo?"),
        ],
        tools: [calculatorTool, weatherTool],
    )

    // Show tool calls organized by namespace
    for step in result.steps {
        for toolCall in step.toolCalls {
            print("Tool: \(toolCall.name)")
            print("  Namespace: \(toolCall.namespace ?? "default")")
            print("  Recipient: \(toolCall.recipient ?? "any")")
            print("  Args: \(toolCall.arguments)")
        }
    }
}

// MARK: - Embeddings Example

func demonstrateEmbeddings() async throws {
    print("\n=== Embeddings Demo ===\n")

    // Single embedding
    let result = try await generateEmbedding(
        model: .openai(.small3),
        input: .text("The quick brown fox jumps over the lazy dog"),
        settings: EmbeddingSettings(
            dimensions: 256,
            normalizeEmbeddings: true,
        ),
    )

    print("Generated embedding with \(result.dimensions ?? 0) dimensions")
    if let embedding = result.embedding {
        print("First 5 values: \(embedding.prefix(5))")
    }

    // Batch embeddings
    let documents = [
        "Machine learning is fascinating",
        "Deep learning uses neural networks",
        "Natural language processing enables AI to understand text",
    ]

    print("\nBatch embeddings:")
    let batchResults = try await generateEmbeddingsBatch(
        model: .openai(.small3),
        inputs: documents.map { .text($0) },
        concurrency: 3,
    )

    for (doc, result) in zip(documents, batchResults) {
        print("  \(doc): \(result.dimensions ?? 0) dims")
    }
}

// MARK: - Response Caching Example

func demonstrateResponseCaching() async throws {
    print("\n=== Response Caching Demo ===\n")

    let cache = ResponseCache(maxSize: 10, ttl: 60)

    // Create a simple request
    let request = ProviderRequest(
        messages: [
            ModelMessage.user("What is 2+2?"),
        ],
        tools: nil,
        settings: .default,
    )

    // First call - no cache
    print("First call (should miss cache):")
    if let cached = await cache.get(for: request) {
        print("  Found in cache!")
    } else {
        print("  Cache miss - calling API...")

        // Simulate API response
        let response = ProviderResponse(
            text: "2+2 equals 4",
            usage: Usage(inputTokens: 10, outputTokens: 5),
            finishReason: .stop,
        )

        // Store in cache
        await cache.store(response, for: request)
        print("  Stored in cache")
    }

    // Second call - should hit cache
    print("\nSecond call (should hit cache):")
    if let cached = await cache.get(for: request) {
        print("  Cache hit! Response: \(cached.text)")
    } else {
        print("  Unexpected cache miss")
    }

    // Show cache statistics
    let stats = await cache.statistics()
    print("\nCache Statistics:")
    print("  Total entries: \(stats.totalEntries)")
    print("  Valid entries: \(stats.validEntries)")
    print("  Cache size limit: \(stats.cacheSize)")
}

// MARK: - Integrated Example

func demonstrateIntegratedFeatures() async throws {
    print("\n=== Integrated Features Demo ===\n")

    // Set up configuration with caching
    let config = TachikomaConfiguration()
    config.setAPIKey("your-api-key", for: .openAI)

    // Create retry handler
    let retryHandler = RetryHandler(policy: .default)

    // Create enhanced tools
    let tools = [
        AgentTool(
            name: "analyze",
            description: "Analyze data",
            parameters: AgentToolParameters(properties: [], required: []),
            namespace: "analytics",
        ) { _ in .string("Analysis complete") },
    ]

    // Generate with all features
    do {
        let result = try await retryHandler.execute {
            try await generateText(
                model: .openai(.gpt4o),
                messages: [
                    .system("You are a helpful assistant. Use channels to organize your response."),
                    .user("Analyze the benefits of functional programming"),
                ],
                tools: tools,
                settings: GenerationSettings(
                    maxTokens: 1000,
                    temperature: 0.7,
                    reasoningEffort: .medium,
                ),
                configuration: config,
            )
        }

        print("Response generated successfully")
        print("Used \(result.usage?.totalTokens ?? 0) tokens")

        // Process by channel
        for message in result.messages {
            if message.role == .assistant {
                let channelName = message.channel?.rawValue ?? "default"
                print("[\(channelName.uppercased())] \(message.content.first?.textValue ?? "")")
            }
        }
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Main

@main
struct HarmonyFeaturesDemo {
    static func main() async {
        print("Tachikoma - OpenAI Harmony Features Demo\n")
        print("=========================================\n")

        do {
            // Note: These demos require API keys to be set
            // You can set them via environment variables or configuration

            // Uncomment to run demos:
            // try await demonstrateMultiChannelResponse()
            // try await demonstrateReasoningEffort()
            // try await demonstrateRetryHandler()
            // try await demonstrateEnhancedTools()
            // try await demonstrateEmbeddings()
            try await demonstrateResponseCaching()
            // try await demonstrateIntegratedFeatures()

            print("\n✅ Demo completed successfully!")
        } catch {
            print("\n❌ Demo failed: \(error)")
        }
    }
}

// MARK: - Helper Extensions

extension AgentToolArgument {
    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var doubleValue: Double? {
        if case let .double(value) = self {
            return value
        }
        return nil
    }
}

extension ModelMessage.ContentPart {
    var textValue: String? {
        if case let .text(value) = self {
            return value
        }
        return nil
    }
}
