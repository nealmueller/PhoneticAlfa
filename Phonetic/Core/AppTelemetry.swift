import Foundation
import os

enum AppTelemetry {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nealmueller.phonetic",
        category: "monetization"
    )

    static func monetizationEvent(_ name: String, source: String? = nil, detail: String? = nil) {
        let sourceText = source ?? "unknown"
        let detailText = detail ?? "-"
        logger.log(
            "event=\(name, privacy: .public) source=\(sourceText, privacy: .public) detail=\(detailText, privacy: .public)"
        )
    }
}

