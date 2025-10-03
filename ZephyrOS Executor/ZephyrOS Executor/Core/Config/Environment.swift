//
//  Environment.swift
//  ZephyrOS Executor
//
//  Environment variable loader for configuration
//

import Foundation

struct Environment {
    // ZMemory API Configuration
    static let zMemoryAPIURL: String = {
        ProcessInfo.processInfo.environment["ZMEMORY_API_URL"] ?? ""
    }()

    static let zMemoryAPIKey: String = {
        ProcessInfo.processInfo.environment["ZMEMORY_API_KEY"] ?? ""
    }()

    // Anthropic Claude API Configuration
    static let anthropicAPIKey: String = {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }()

    // Google OAuth Configuration
    static let googleClientID: String = {
        ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
    }()

    static let googleClientSecret: String = {
        ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? ""
    }()

    static let googleRedirectURI: String = {
        ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"] ?? "com.zephyros.executor:/oauth/callback"
    }()

    // Supabase Configuration (for authentication)
    static let supabaseURL: String = {
        ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    }()

    static let supabaseAnonKey: String = {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    }()

    // Executor Configuration
    static let agentName: String = {
        ProcessInfo.processInfo.environment["AGENT_NAME"] ?? "zephyr-executor-1"
    }()

    static let maxConcurrentTasks: Int = {
        if let value = ProcessInfo.processInfo.environment["MAX_CONCURRENT_TASKS"],
           let intValue = Int(value) {
            return intValue
        }
        return 2
    }()

    static let pollingIntervalSeconds: Int = {
        if let value = ProcessInfo.processInfo.environment["POLLING_INTERVAL_SECONDS"],
           let intValue = Int(value) {
            return intValue
        }
        return 30
    }()

    // Helper to check if all required environment variables are set
    static var isConfigured: Bool {
        !googleClientID.isEmpty &&
        !zMemoryAPIURL.isEmpty &&
        !anthropicAPIKey.isEmpty
    }

    // Helper to load .env file (for development)
    static func loadDotEnv(from path: String? = nil) {
        let envPath = path ?? findEnvFile()
        guard let envPath = envPath else {
            return
        }

        guard let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return
        }

        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            // Skip comments and empty lines
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE
            let parts = trimmedLine.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                setenv(key, value, 1)
            }
        }
    }

    // Find .env file in project directory
    private static func findEnvFile() -> String? {
        // Try to find .env in the project root
        let fileManager = FileManager.default

        // Get the executable path and work backwards to find project root
        var currentPath = Bundle.main.bundlePath

        for _ in 0..<10 { // Search up to 10 levels
            let envPath = (currentPath as NSString).appendingPathComponent(".env")
            if fileManager.fileExists(atPath: envPath) {
                return envPath
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }

        // Try common development paths
        let devPaths = [
            NSString(string: "~/.zephyros-executor/.env").expandingTildeInPath,
            "./env",
            "../.env",
            "../../.env"
        ]

        for path in devPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }
}
