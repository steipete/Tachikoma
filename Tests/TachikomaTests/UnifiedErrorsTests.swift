import Foundation
import Testing
@testable import Tachikoma

@Suite("Unified Errors Tests")
struct UnifiedErrorsTests {
    @Test("Create unified error with recovery suggestion")
    func unifiedErrorWithRecovery() throws {
        let error = TachikomaUnifiedError(
            code: .authenticationFailed,
            message: "Invalid API key provided",
            recovery: .checkAPIKey,
        )

        #expect(error.code == .authenticationFailed)
        #expect(error.message == "Invalid API key provided")
        #expect(error.recovery?.suggestion.contains("API key") == true)
        #expect(error.recovery?.actions.contains(.validateAPIKey) == true)

        // Check error description
        let description = error.errorDescription
        #expect(description?.contains("Invalid API key provided") == true)
    }

    @Test("Convert legacy TachikomaError to unified error")
    func legacyErrorConversion() throws {
        let legacyError = TachikomaError.modelNotFound("gpt-5")
        let unifiedError = legacyError.toUnifiedError()

        #expect(unifiedError.code == .modelNotFound)
        #expect(unifiedError.message.contains("gpt-5") == true)
        #expect(unifiedError.recovery?.actions.contains(.selectDifferentModel) == true)
    }

    @Test("Convert ModelError to unified error")
    func modelErrorConversion() throws {
        let modelError = ModelError.rateLimited(retryAfter: 60)
        let unifiedError = modelError.toUnifiedError()

        #expect(unifiedError.code == .rateLimited)
        #expect(unifiedError.details?.retryAfter == 60)
        #expect(unifiedError.recovery?.actions.contains {
            if case .retry(after: 60) = $0 { return true }
            return false
        } == true)
    }

    @Test("Convert AgentToolError to unified error")
    func agentToolErrorConversion() throws {
        let toolError = AgentToolError.missingParameter("expression")
        let unifiedError = toolError.toUnifiedError()

        #expect(unifiedError.code == .missingParameter)
        #expect(unifiedError.message.contains("expression") == true)
    }

    @Test("Error details with metadata")
    func errorDetails() throws {
        let details = ErrorDetails(
            reason: "Token limit exceeded",
            statusCode: 429,
            responseBody: "{\"error\": \"rate_limit\"}",
            provider: "openai",
            modelId: "gpt-4",
            requestId: "req-123",
            retryAfter: 30,
            metadata: ["tokens_used": "5000"],
        )

        #expect(details.statusCode == 429)
        #expect(details.provider == "openai")
        #expect(details.retryAfter == 30)
        #expect(details.metadata["tokens_used"] == "5000")
    }

    @Test("Recovery suggestion with actions")
    func testRecoverySuggestion() throws {
        let recovery = RecoverySuggestion(
            suggestion: "Reduce request size and try again",
            actions: [
                .reduceRequestSize,
                .retry(after: 5),
            ],
            helpURL: "https://docs.example.com/errors",
        )

        #expect(recovery.actions.count == 2)
        #expect(recovery.helpURL == "https://docs.example.com/errors")
    }

    @Test("Error code categories")
    func errorCodeCategories() throws {
        #expect(ErrorCode.invalidRequest.category == .validation)
        #expect(ErrorCode.authenticationFailed.category == .authentication)
        #expect(ErrorCode.rateLimited.category == .rateLimit)
        #expect(ErrorCode.modelNotFound.category == .model)
        #expect(ErrorCode.networkError.category == .network)
        #expect(ErrorCode.toolExecutionFailed.category == .tool)
        #expect(ErrorCode.parsingError.category == .parsing)
    }

    @Test("Generic error conversion")
    func genericErrorConversion() throws {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "Custom error occurred" }
        }

        let customError = CustomError()
        let unifiedError = customError.toTachikomaError()

        #expect(unifiedError.code == .serverError)
        #expect(unifiedError.message == "Custom error occurred")
        #expect(unifiedError.underlyingError != nil)
    }

    @Test("API call error conversion")
    func aPICallErrorConversion() throws {
        let apiError = APICallError(
            statusCode: 500,
            responseBody: "Internal server error",
            provider: "anthropic",
            modelId: "claude-3",
            requestId: "req-456",
            errorType: .serverError,
            message: "Server encountered an error",
            retryAfter: nil,
        )

        let tachikomaError = TachikomaError.apiCallError(apiError)
        let unifiedError = tachikomaError.toUnifiedError()

        #expect(unifiedError.code.rawValue.contains("server_error") == true)
        #expect(unifiedError.details?.statusCode == 500)
        #expect(unifiedError.details?.provider == "anthropic")
        #expect(unifiedError.details?.requestId == "req-456")
    }

    @Test("Retry error conversion")
    func retryErrorConversion() throws {
        let retryError = RetryError(
            reason: "All attempts failed",
            lastError: TachikomaError.networkError(NSError(domain: "test", code: -1)),
            errors: [],
            attempts: 3,
        )

        let tachikomaError = TachikomaError.retryError(retryError)
        let unifiedError = tachikomaError.toUnifiedError()

        #expect(unifiedError.code == .serverError)
        #expect(unifiedError.details?.reason?.contains("3 attempts") == true)
        #expect(unifiedError.underlyingError != nil)
    }

    @Test("Error with nil recovery")
    func errorWithoutRecovery() throws {
        let error = TachikomaUnifiedError(
            code: .invalidParameter,
            message: "Invalid parameter value",
            recovery: nil,
        )

        #expect(error.recovery == nil)
        #expect(error.recoverySuggestion == nil)
        #expect(error.helpAnchor == nil)
    }
}
