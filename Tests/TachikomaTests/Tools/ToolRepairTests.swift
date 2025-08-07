//
//  ToolRepairTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma

@Suite("Tool Repair Mechanisms Tests")
struct ToolRepairTests {
    
    @Test("ParameterRepairStrategy fixes missing parameters")
    func testParameterRepairMissingParams() async throws {
        let strategy = ParameterRepairStrategy()
        
        let toolCall = AgentToolCall(
            name: "search",
            arguments: [
                "query": .null,
                "limit": .null
            ]
        )
        
        struct MissingParamError: Error, LocalizedError {
            var errorDescription: String? { "Required parameter 'query' is missing" }
        }
        
        let repaired = try await strategy.repair(
            toolCall: toolCall,
            error: MissingParamError(),
            attempt: 1
        )
        
        // Should provide defaults for null values
        #expect(repaired != nil)
        if let repaired {
            #expect(repaired.arguments["query"] != .null)
            #expect(repaired.arguments["limit"] != .null)
        }
    }
    
    @Test("ParameterRepairStrategy fixes type mismatches")
    func testParameterRepairTypeMismatch() async throws {
        let strategy = ParameterRepairStrategy()
        
        let toolCall = AgentToolCall(
            name: "calculate",
            arguments: [
                "count": .string("42"),  // Should be integer
                "enabled": .string("true")  // Should be boolean
            ]
        )
        
        struct TypeMismatchError: Error, LocalizedError {
            var errorDescription: String? { "Type mismatch: expected integer for 'count'" }
        }
        
        let repaired = try await strategy.repair(
            toolCall: toolCall,
            error: TypeMismatchError(),
            attempt: 1
        )
        
        #expect(repaired != nil)
        if let repaired {
            // String "42" should be converted to integer
            #expect(repaired.arguments["count"] == .int(42))
            // String "true" should be converted to boolean
            #expect(repaired.arguments["enabled"] == .bool(true))
        }
    }
    
    @Test("ParameterRepairStrategy clamps out-of-range values")
    func testParameterRepairRangeClamp() async throws {
        let strategy = ParameterRepairStrategy()
        
        let toolCall = AgentToolCall(
            name: "generate",
            arguments: [
                "temperature": .double(5.0),  // Too high, should be clamped to 2.0
                "limit": .int(500),  // Too high, should be clamped to 100
                "page": .int(-5)  // Negative, should be clamped to 0
            ]
        )
        
        struct RangeError: Error, LocalizedError {
            var errorDescription: String? { "Value out of range: temperature must be between 0 and 2" }
        }
        
        let repaired = try await strategy.repair(
            toolCall: toolCall,
            error: RangeError(),
            attempt: 1
        )
        
        #expect(repaired != nil)
        if let repaired {
            #expect(repaired.arguments["temperature"] == .double(2.0))
            #expect(repaired.arguments["limit"] == .int(100))
            #expect(repaired.arguments["page"] == .int(0))
        }
    }
    
    @Test("ParameterRepairStrategy returns nil when no repair needed")
    func testParameterRepairNoChange() async throws {
        let strategy = ParameterRepairStrategy()
        
        let toolCall = AgentToolCall(
            name: "valid",
            arguments: [
                "name": .string("test"),
                "value": .int(42)
            ]
        )
        
        struct UnrelatedError: Error, LocalizedError {
            var errorDescription: String? { "Network timeout" }
        }
        
        let repaired = try await strategy.repair(
            toolCall: toolCall,
            error: UnrelatedError(),
            attempt: 1
        )
        
        // No repair needed for unrelated error
        #expect(repaired == nil)
    }
    
    @Test("ResilientToolExecutor retries on failure")
    func testResilientExecutorRetry() async throws {
        var attemptCount = 0
        
        let tool = AgentTool(
            name: "flaky_tool",
            description: "Sometimes fails",
            parameters: AgentToolParameters(properties: [], required: [])
        ) { _ in
            attemptCount += 1
            if attemptCount < 3 {
                throw TachikomaError.toolCallFailed("Temporary failure")
            }
            return .string("Success on attempt \(attemptCount)")
        }
        
        let executor = ResilientToolExecutor(
            maxRetries: 3,
            repairStrategy: nil,
            retryDelay: 0.01
        )
        
        let call = AgentToolCall(name: "flaky_tool", arguments: [:])
        let result = try await executor.execute(tool: tool, call: call)
        
        #expect(attemptCount == 3)
        #expect(result.isError == false)
        #expect(result.result == .string("Success on attempt 3"))
    }
    
    @Test("ResilientToolExecutor applies repair strategy")
    func testResilientExecutorWithRepair() async throws {
        let tool = AgentTool(
            name: "strict_tool",
            description: "Requires specific parameters",
            parameters: AgentToolParameters(
                properties: ["required_param": AgentToolParameterProperty(
                    name: "required_param",
                    type: .string,
                    description: "Required"
                )],
                required: ["required_param"]
            )
        ) { args in
            guard case .string = args["required_param"] else {
                throw TachikomaError.invalidInput("Missing required_param")
            }
            return .string("Success with \(args["required_param"] ?? .null)")
        }
        
        let executor = ResilientToolExecutor(
            maxRetries: 2,
            repairStrategy: ParameterRepairStrategy(),
            retryDelay: 0.01
        )
        
        // Call with missing parameter
        let call = AgentToolCall(
            name: "strict_tool",
            arguments: ["required_param": .null]
        )
        
        let result = try await executor.execute(tool: tool, call: call)
        
        // Should succeed after repair
        #expect(result.isError == false)
    }
    
    @Test("ResilientToolExecutor returns error after max retries")
    func testResilientExecutorMaxRetries() async throws {
        let tool = AgentTool(
            name: "always_fails",
            description: "Always fails",
            parameters: AgentToolParameters(properties: [], required: [])
        ) { _ in
            throw TachikomaError.toolCallFailed("Permanent failure")
        }
        
        let executor = ResilientToolExecutor(
            maxRetries: 2,
            repairStrategy: nil,
            retryDelay: 0.01
        )
        
        let call = AgentToolCall(name: "always_fails", arguments: [:])
        let result = try await executor.execute(tool: tool, call: call)
        
        #expect(result.isError == true)
        if case .string(let errorMsg) = result.result {
            #expect(errorMsg.contains("failed after 2 attempts"))
        }
    }
    
    @Test("ResilientToolExecutor executeAll parallel execution")
    func testResilientExecutorParallel() async throws {
        var executionOrder: [String] = []
        let lock = NSLock()
        
        let tool1 = AgentTool(
            name: "tool1",
            description: "First tool",
            parameters: AgentToolParameters(properties: [], required: [])
        ) { _ in
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            lock.lock()
            executionOrder.append("tool1")
            lock.unlock()
            return .string("Result 1")
        }
        
        let tool2 = AgentTool(
            name: "tool2",
            description: "Second tool",
            parameters: AgentToolParameters(properties: [], required: [])
        ) { _ in
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            lock.lock()
            executionOrder.append("tool2")
            lock.unlock()
            return .string("Result 2")
        }
        
        let executor = ResilientToolExecutor(maxRetries: 1)
        
        let calls = [
            AgentToolCall(name: "tool1", arguments: [:]),
            AgentToolCall(name: "tool2", arguments: [:])
        ]
        
        let results = try await executor.executeAll(
            tools: [tool1, tool2],
            calls: calls
        )
        
        #expect(results.count == 2)
        // tool2 should complete first due to shorter sleep
        #expect(executionOrder == ["tool2", "tool1"])
    }
    
    @Test("CompositeRepairStrategy combines multiple strategies")
    func testCompositeRepairStrategy() async throws {
        // Custom strategy that adds a prefix
        struct PrefixStrategy: ToolRepairStrategy {
            func repair(
                toolCall: AgentToolCall,
                error: Error,
                attempt: Int
            ) async throws -> AgentToolCall? {
                var modified = toolCall.arguments
                for (key, value) in modified {
                    if case .string(let str) = value {
                        modified[key] = .string("prefix_\(str)")
                    }
                }
                return AgentToolCall(
                    id: toolCall.id,
                    name: toolCall.name,
                    arguments: modified
                )
            }
        }
        
        let composite = CompositeRepairStrategy(strategies: [
            PrefixStrategy(),
            ParameterRepairStrategy()
        ])
        
        let toolCall = AgentToolCall(
            name: "test",
            arguments: [
                "text": .string("value"),
                "count": .string("10")  // Will be converted to int
            ]
        )
        
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Type error" }
        }
        
        let repaired = try await composite.repair(
            toolCall: toolCall,
            error: TestError(),
            attempt: 1
        )
        
        #expect(repaired != nil)
        if let repaired {
            // Prefix should be added
            #expect(repaired.arguments["text"] == .string("prefix_value"))
            // Type should be converted
            #expect(repaired.arguments["count"] == .int(10))
        }
    }
    
    @Test("Inference of default values based on parameter names")
    func testDefaultValueInference() async throws {
        let strategy = ParameterRepairStrategy()
        
        let testCases: [(String, AgentToolArgument)] = [
            ("count", .int(10)),
            ("limit", .int(10)),
            ("max_items", .int(10)),
            ("page", .int(0)),
            ("offset", .int(0)),
            ("query", .string("")),
            ("search_term", .string("")),
            ("enabled", .bool(true)),
            ("is_active", .bool(true)),
            ("temperature", .double(0.7))
        ]
        
        for (paramName, expectedDefault) in testCases {
            let toolCall = AgentToolCall(
                name: "test",
                arguments: [paramName: .null]
            )
            
            struct MissingError: Error, LocalizedError {
                var errorDescription: String? { "Missing required parameter" }
            }
            
            let repaired = try await strategy.repair(
                toolCall: toolCall,
                error: MissingError(),
                attempt: 1
            )
            
            #expect(repaired?.arguments[paramName] == expectedDefault)
        }
    }
}