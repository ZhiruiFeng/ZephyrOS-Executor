//
//  ClaudeClient.swift
//  ZephyrOS Executor
//
//  Client for Anthropic Claude API
//

import Foundation

class ClaudeClient {
    private let apiKey: String
    private let model: String
    private let maxTokens: Int
    private let session: URLSession
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String, model: String = "claude-sonnet-4-20250514", maxTokens: Int = 4096) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Methods

    func testConnection() async throws -> Bool {
        // Send a minimal test request
        let testRequest = ClaudeRequest(
            model: model,
            maxTokens: 10,
            messages: [ClaudeMessage(role: "user", content: "Hello")]
        )

        do {
            _ = try await sendRequest(testRequest)
            return true
        } catch {
            return false
        }
    }

    func executeTask(description: String, context: [String: Any]? = nil) async throws -> TaskResult {
        let startTime = Date()
        let prompt = buildPrompt(description: description, context: context)

        let request = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )

        let response = try await sendRequest(request)

        // Extract text from response
        let responseText = response.content.compactMap { block in
            if block.type == "text", let text = block.text {
                return text
            }
            return nil
        }.joined()

        let executionTime = Date().timeIntervalSince(startTime)

        return TaskResult(
            response: responseText,
            usage: TokenUsage(
                inputTokens: response.usage.inputTokens,
                outputTokens: response.usage.outputTokens,
                totalTokens: response.usage.inputTokens + response.usage.outputTokens
            ),
            model: model,
            executionTimeSeconds: executionTime
        )
    }

    // MARK: - Helper Methods

    private func sendRequest(_ request: ClaudeRequest) async throws -> ClaudeResponse {
        var urlRequest = URLRequest(url: apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaudeError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ClaudeResponse.self, from: data)
    }

    private func buildPrompt(description: String, context: [String: Any]?) -> String {
        var parts = [
            "You are ZephyrOS Executor, an AI assistant that completes coding and development tasks.",
            "",
            "TASK:",
            description
        ]

        if let context = context, !context.isEmpty {
            parts.append("")
            parts.append("ADDITIONAL CONTEXT:")
            for (key, value) in context {
                parts.append("\(key): \(value)")
            }
        }

        parts.append("")
        parts.append("Please complete this task and provide detailed output including:")
        parts.append("1. Your approach and reasoning")
        parts.append("2. Any code or artifacts generated")
        parts.append("3. Next steps or recommendations")

        return parts.joined(separator: "\n")
    }
}

// MARK: - Request/Response Models

struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Encodable {
    let role: String
    let content: String
}

struct ClaudeResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let usage: Usage

    struct ContentBlock: Decodable {
        let type: String
        let text: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            text = try container.decodeIfPresent(String.self, forKey: .text)
        }

        enum CodingKeys: String, CodingKey {
            case type, text
        }
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .httpError(let code):
            return "Claude API error: HTTP \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
