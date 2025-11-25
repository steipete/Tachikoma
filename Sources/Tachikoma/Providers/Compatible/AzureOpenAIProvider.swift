import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider for Azure-hosted OpenAI deployments
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class AzureOpenAIProvider: ModelProvider {
    public let modelId: String
    public let apiVersion: String
    public let capabilities: ModelCapabilities
    public var baseURL: String? { self.resolvedBaseURL }
    public var apiKey: String? { self.resolvedAPIKey }

    private let authHeaderName: String
    private let authHeaderValuePrefix: String
    private let resolvedAPIKey: String
    private let resolvedBaseURL: String
    private let configuration: TachikomaConfiguration
    private let session: URLSession

    public init(
        deploymentId: String,
        resource: String?,
        apiVersion: String?,
        endpoint: String?,
        configuration: TachikomaConfiguration,
        session: URLSession = .shared,
    ) throws {
        self.modelId = deploymentId
        self.configuration = configuration
        self.session = session

        // Base URL resolution: explicit endpoint > configured base > env endpoint > resource name
        let envEndpoint = Provider.environmentValue(for: "AZURE_OPENAI_ENDPOINT")
        let envResource = Provider.environmentValue(for: "AZURE_OPENAI_RESOURCE")

        if
            let explicitEndpoint = endpoint ?? configuration.getBaseURL(for: .azureOpenAI) ?? envEndpoint,
            !explicitEndpoint.isEmpty
        {
            if explicitEndpoint.contains("://") {
                self.resolvedBaseURL = explicitEndpoint
            } else {
                self.resolvedBaseURL = "https://\(explicitEndpoint)"
            }
        } else if let resourceName = resource ?? envResource, !resourceName.isEmpty {
            self.resolvedBaseURL = "https://\(resourceName).openai.azure.com"
        } else {
            throw TachikomaError.invalidConfiguration(
                "Azure OpenAI requires either endpoint or resource (set AZURE_OPENAI_ENDPOINT or AZURE_OPENAI_RESOURCE).",
            )
        }

        // API version resolution
        let envAPIVersion = Provider.environmentValue(for: "AZURE_OPENAI_API_VERSION")
        self.apiVersion = apiVersion ?? envAPIVersion ?? configuration.azureOpenAIDefaultAPIVersion

        // Auth resolution: prefer bearer token, fall back to API key
        let bearerToken = Provider.environmentValue(for: "AZURE_OPENAI_BEARER_TOKEN") ??
            Provider.environmentValue(for: "AZURE_OPENAI_TOKEN")
        if let bearerToken, !bearerToken.isEmpty {
            self.authHeaderName = "Authorization"
            self.authHeaderValuePrefix = "Bearer "
            self.resolvedAPIKey = bearerToken
        } else if let key = configuration.getAPIKey(for: .azureOpenAI) {
            self.authHeaderName = "api-key"
            self.authHeaderValuePrefix = ""
            self.resolvedAPIKey = key
        } else if
            let envKey = Provider.environmentValue(for: Provider.azureOpenAI.environmentVariable, isSecret: true),
            !envKey.isEmpty
        {
            self.authHeaderName = "api-key"
            self.authHeaderValuePrefix = ""
            self.resolvedAPIKey = envKey
        } else {
            throw TachikomaError.authenticationFailed("Missing Azure OpenAI credentials (api-key or bearer token).")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: true,
            supportsTools: true,
            supportsStreaming: true,
            contextLength: 128_000,
            maxOutputTokens: 4096,
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        try await OpenAICompatibleHelper.generateText(
            request: request,
            modelId: self.modelId,
            baseURL: self.resolvedBaseURL,
            apiKey: self.resolvedAPIKey,
            providerName: "AzureOpenAI",
            path: "/openai/deployments/\(self.modelId)/chat/completions",
            queryItems: [URLQueryItem(name: "api-version", value: self.apiVersion)],
            authHeaderName: self.authHeaderName,
            authHeaderValuePrefix: self.authHeaderValuePrefix,
            session: self.session,
        )
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        try await OpenAICompatibleHelper.streamText(
            request: request,
            modelId: self.modelId,
            baseURL: self.resolvedBaseURL,
            apiKey: self.resolvedAPIKey,
            providerName: "AzureOpenAI",
            path: "/openai/deployments/\(self.modelId)/chat/completions",
            queryItems: [URLQueryItem(name: "api-version", value: self.apiVersion)],
            authHeaderName: self.authHeaderName,
            authHeaderValuePrefix: self.authHeaderValuePrefix,
            session: self.session,
        )
    }
}
