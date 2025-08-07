//
//  StopConditionsTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma

@Suite("Stop Conditions Tests")
struct StopConditionsTests {
    
    @Test("StepCountCondition stops at max steps")
    func testStepCountCondition() async throws {
        let condition = StepCountCondition(maxSteps: 3)
        
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: []) == false)
        #expect(await condition.shouldStop(step: 1, toolCalls: [], results: []) == false)
        #expect(await condition.shouldStop(step: 2, toolCalls: [], results: []) == false)
        #expect(await condition.shouldStop(step: 3, toolCalls: [], results: []) == true)
        #expect(await condition.shouldStop(step: 4, toolCalls: [], results: []) == true)
    }
    
    @Test("ToolCalledCondition stops when tool is called")
    func testToolCalledCondition() async throws {
        let condition = ToolCalledCondition(toolName: "search")
        
        let toolCalls1 = [
            AgentToolCall(name: "calculate", arguments: [:])
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: toolCalls1, results: []) == false)
        
        let toolCalls2 = [
            AgentToolCall(name: "calculate", arguments: [:]),
            AgentToolCall(name: "search", arguments: [:])
        ]
        #expect(await condition.shouldStop(step: 1, toolCalls: toolCalls2, results: []) == true)
    }
    
    @Test("ResultTypeCondition stops on matching result")
    func testResultTypeCondition() async throws {
        let condition = ResultTypeCondition { result in
            if case .string(let str) = result.result {
                return str.contains("STOP")
            }
            return false
        }
        
        let results1 = [
            AgentToolResult(toolCallId: "1", result: .string("Continue"), isError: false)
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: results1) == false)
        
        let results2 = [
            AgentToolResult(toolCallId: "1", result: .string("Continue"), isError: false),
            AgentToolResult(toolCallId: "2", result: .string("STOP NOW"), isError: false)
        ]
        #expect(await condition.shouldStop(step: 1, toolCalls: [], results: results2) == true)
    }
    
    @Test("ErrorCondition stops on error")
    func testErrorCondition() async throws {
        let condition = ErrorCondition()
        
        let results1 = [
            AgentToolResult(toolCallId: "1", result: .string("Success"), isError: false)
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: results1) == false)
        
        let results2 = [
            AgentToolResult(toolCallId: "1", result: .string("Success"), isError: false),
            AgentToolResult(toolCallId: "2", result: .string("Error"), isError: true)
        ]
        #expect(await condition.shouldStop(step: 1, toolCalls: [], results: results2) == true)
    }
    
    @Test("AndCondition requires all conditions")
    func testAndCondition() async throws {
        let condition = AndCondition(
            StepCountCondition(maxSteps: 2),
            ErrorCondition()
        )
        
        // Step 0, no error - should not stop
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: []) == false)
        
        // Step 2, no error - should not stop (only step condition met)
        #expect(await condition.shouldStop(step: 2, toolCalls: [], results: []) == false)
        
        // Step 2, with error - should stop (both conditions met)
        let errorResults = [
            AgentToolResult(toolCallId: "1", result: .string("Error"), isError: true)
        ]
        #expect(await condition.shouldStop(step: 2, toolCalls: [], results: errorResults) == true)
    }
    
    @Test("OrCondition requires any condition")
    func testOrCondition() async throws {
        let condition = OrCondition(
            StepCountCondition(maxSteps: 5),
            ErrorCondition()
        )
        
        // Step 0, no error - should not stop
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: []) == false)
        
        // Step 5, no error - should stop (step condition met)
        #expect(await condition.shouldStop(step: 5, toolCalls: [], results: []) == true)
        
        // Step 2, with error - should stop (error condition met)
        let errorResults = [
            AgentToolResult(toolCallId: "1", result: .string("Error"), isError: true)
        ]
        #expect(await condition.shouldStop(step: 2, toolCalls: [], results: errorResults) == true)
    }
    
    @Test("CustomCondition with closure")
    func testCustomCondition() async throws {
        let condition = CustomCondition { step, toolCalls, results in
            // Stop if we have more than 2 tool calls or step > 3
            toolCalls.count > 2 || step > 3
        }
        
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: []) == false)
        #expect(await condition.shouldStop(step: 4, toolCalls: [], results: []) == true)
        
        let manyTools = [
            AgentToolCall(name: "tool1", arguments: [:]),
            AgentToolCall(name: "tool2", arguments: [:]),
            AgentToolCall(name: "tool3", arguments: [:])
        ]
        #expect(await condition.shouldStop(step: 1, toolCalls: manyTools, results: []) == true)
    }
    
    @Test("StopWhen builder methods")
    func testStopWhenBuilder() async throws {
        // Test stepCountIs
        let stepCondition = StopWhen.stepCountIs(3)
        #expect(await stepCondition.shouldStop(step: 3, toolCalls: [], results: []) == true)
        
        // Test toolCalled
        let toolCondition = StopWhen.toolCalled("search")
        let searchCall = [AgentToolCall(name: "search", arguments: [:])]
        #expect(await toolCondition.shouldStop(step: 0, toolCalls: searchCall, results: []) == true)
        
        // Test errorOccurs
        let errorCondition = StopWhen.errorOccurs()
        let errorResult = [AgentToolResult(toolCallId: "1", result: .string("Error"), isError: true)]
        #expect(await errorCondition.shouldStop(step: 0, toolCalls: [], results: errorResult) == true)
        
        // Test never
        let neverCondition = StopWhen.never()
        #expect(await neverCondition.shouldStop(step: 1000, toolCalls: [], results: []) == false)
    }
    
    @Test("StopWhen resultContains")
    func testStopWhenResultContains() async throws {
        let condition = StopWhen.resultContains { result in
            if case .int(let value) = result.result {
                return value > 100
            }
            return false
        }
        
        let smallResult = [
            AgentToolResult(toolCallId: "1", result: .int(50), isError: false)
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: smallResult) == false)
        
        let largeResult = [
            AgentToolResult(toolCallId: "1", result: .int(150), isError: false)
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: largeResult) == true)
    }
    
    @Test("StopWhen resultMatches")
    func testStopWhenResultMatches() async throws {
        let condition = StopWhen.resultMatches("COMPLETE")
        
        let results1 = [
            AgentToolResult(toolCallId: "1", result: .string("Processing..."), isError: false)
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: results1) == false)
        
        let results2 = [
            AgentToolResult(toolCallId: "1", result: .string("Task COMPLETE"), isError: false)
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: results2) == true)
        
        // Test with object containing matching string
        let results3 = [
            AgentToolResult(
                toolCallId: "1",
                result: .object(["status": .string("COMPLETE"), "data": .int(42)]),
                isError: false
            )
        ]
        #expect(await condition.shouldStop(step: 0, toolCalls: [], results: results3) == true)
    }
    
    @Test("StopWhen all conditions")
    func testStopWhenAll() async throws {
        let condition = StopWhen.all(
            StopWhen.stepCountIs(2),
            StopWhen.toolCalled("search")
        )
        
        // Only step condition met
        #expect(await condition.shouldStop(step: 2, toolCalls: [], results: []) == false)
        
        // Both conditions met
        let searchCall = [AgentToolCall(name: "search", arguments: [:])]
        #expect(await condition.shouldStop(step: 2, toolCalls: searchCall, results: []) == true)
    }
    
    @Test("StopWhen any conditions")
    func testStopWhenAny() async throws {
        let condition = StopWhen.any(
            StopWhen.stepCountIs(10),
            StopWhen.errorOccurs()
        )
        
        // Neither condition met
        #expect(await condition.shouldStop(step: 5, toolCalls: [], results: []) == false)
        
        // Error condition met
        let errorResult = [AgentToolResult(toolCallId: "1", result: .string("Error"), isError: true)]
        #expect(await condition.shouldStop(step: 5, toolCalls: [], results: errorResult) == true)
        
        // Step condition met
        #expect(await condition.shouldStop(step: 10, toolCalls: [], results: []) == true)
    }
    
    @Test("StopCondition extensions")
    func testStopConditionExtensions() async throws {
        let stepCondition = StopWhen.stepCountIs(5)
        let errorCondition = StopWhen.errorOccurs()
        
        // Test or extension
        let orCondition = stepCondition.or(errorCondition)
        #expect(await orCondition.shouldStop(step: 5, toolCalls: [], results: []) == true)
        let errorResult = [AgentToolResult(toolCallId: "1", result: .string("Error"), isError: true)]
        #expect(await orCondition.shouldStop(step: 2, toolCalls: [], results: errorResult) == true)
        
        // Test and extension
        let andCondition = stepCondition.and(errorCondition)
        #expect(await andCondition.shouldStop(step: 5, toolCalls: [], results: []) == false)
        #expect(await andCondition.shouldStop(step: 5, toolCalls: [], results: errorResult) == true)
        
        // Test not extension
        let notCondition = stepCondition.not()
        #expect(await notCondition.shouldStop(step: 4, toolCalls: [], results: []) == true)
        #expect(await notCondition.shouldStop(step: 5, toolCalls: [], results: []) == false)
    }
    
    @Test("Complex nested conditions")
    func testComplexNestedConditions() async throws {
        // (Step >= 3 OR Error) AND ToolCalled("finish")
        let condition = StopWhen.any(
            StopWhen.stepCountIs(3),
            StopWhen.errorOccurs()
        ).and(StopWhen.toolCalled("finish"))
        
        // Step 3, no finish tool - should not stop
        #expect(await condition.shouldStop(step: 3, toolCalls: [], results: []) == false)
        
        // Step 3, with finish tool - should stop
        let finishCall = [AgentToolCall(name: "finish", arguments: [:])]
        #expect(await condition.shouldStop(step: 3, toolCalls: finishCall, results: []) == true)
        
        // Step 1, error, no finish tool - should not stop
        let errorResult = [AgentToolResult(toolCallId: "1", result: .string("Error"), isError: true)]
        #expect(await condition.shouldStop(step: 1, toolCalls: [], results: errorResult) == false)
        
        // Step 1, error, with finish tool - should stop
        #expect(await condition.shouldStop(step: 1, toolCalls: finishCall, results: errorResult) == true)
    }
}