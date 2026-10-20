//
//  AnalyticsService.swift
//  Easydict
//
//  Created by tisfeng on 2025/12/22.
//  Copyright © 2025 izual. All rights reserved.
//

import Foundation

/// Provides analytics and crash logging utilities.
@objc(EZAnalyticsService)
@objcMembers
final class AnalyticsService: NSObject {
    /// Keeps the upstream API available without initializing remote telemetry in ME-Dict.
    @objc(setupCrashLogService)
    static func setupCrashService() {}

    /// Remote crash reporting remains disabled regardless of legacy preferences.
    static func setCrashEnabled(_ enabled: Bool) {}

    /// Preserves call-site compatibility while disabling upstream analytics collection.
    @objc(logEventWithName:parameters:)
    static func logEvent(withName name: String, parameters: [String: Any]?) {}

    /// Logs window appearance events.
    @objc(logWindowAppear:)
    static func logWindowAppear(_ windowType: EZWindowType) {
        let windowName = EZEnumTypes.windowName(windowType)
        let name = "show_\(windowName)"
        logEvent(withName: name, parameters: nil)
    }

    /// Logs query service usage for analytics.
    @objc(logQueryService:)
    static func logQueryService(_ service: QueryService) {
        let model = service.queryModel

        let textLengthRange = textLengthRange(model.queryText)
        let parameters: [String: Any] = [
            "serviceType": service.serviceType().rawValue,
            "actionType": model.actionType.rawValue,
            "from": model.queryFromLanguage.rawValue,
            "to": model.queryTargetLanguage.rawValue,
            "textLength": textLengthRange,
        ]
        logEvent(withName: "query_service", parameters: parameters)
    }

    /// Returns a human-readable text length range.
    static func textLengthRange(_ text: String) -> String {
        let length = text.utf16.count
        if length <= 10 {
            return "1-10"
        } else if length <= 50 {
            return "10-50"
        } else if length <= 200 {
            return "50-200"
        } else if length <= 1000 {
            return "200-1000"
        } else if length <= 5000 {
            return "1000-5000"
        } else {
            return "5000-∞"
        }
    }

    /// Logs basic app information for analytics.
    static func logAppInfo() {
        let version = DeviceSystemInfo.getSystemVersion()
        let parameters: [String: Any] = [
            "system_version": version,
        ]
        logEvent(withName: "app_info", parameters: parameters)
    }
}
