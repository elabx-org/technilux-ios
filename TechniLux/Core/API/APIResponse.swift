import Foundation

/// Generic API response wrapper matching Technitium's response format
struct ApiResponse<T: Decodable>: Decodable {
    let status: ResponseStatus
    let response: T?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case status
        case response
        case errorMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(ResponseStatus.self, forKey: .status)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)

        // Response might be at root level or nested in "response" key
        // First try nested "response" key (most endpoints)
        if container.contains(.response) {
            response = try container.decodeIfPresent(T.self, forKey: .response)
        } else {
            // Try decoding from root level (for login/session endpoints)
            response = try T(from: decoder)
        }
    }
}

/// API response status
enum ResponseStatus: String, Decodable {
    case ok
    case error
    case invalidToken = "invalid-token"
}

/// Empty response for endpoints that don't return data
struct EmptyResponse: Decodable {}

/// Error types for API operations
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidToken
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidToken:
            return "Session expired. Please login again."
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
