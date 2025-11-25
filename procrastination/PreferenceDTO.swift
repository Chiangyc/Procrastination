// PreferenceDTO.swift
import Foundation

/// 專門給 GeminiService 用的偏好 DTO（全部用 String）
struct PreferenceDTO: Codable {
    let arrangeStrategy: String
    let weekdayWeekend: String
    let focusSpan: String
    let longTask: String
}

