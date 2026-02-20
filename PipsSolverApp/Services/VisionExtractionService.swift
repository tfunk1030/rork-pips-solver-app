import UIKit
import Foundation

nonisolated final class VisionExtractionService: Sendable {

    private let toolkitURL: String

    init(toolkitURL: String) {
        self.toolkitURL = toolkitURL
    }

    func extractPuzzle(from image: UIImage) async throws -> Puzzle {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw ExtractionError.invalidImage
        }
        let base64 = imageData.base64EncodedString()

        let prompt = buildExtractionPrompt()

        let messageContent: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image", "image": "data:image/jpeg;base64,\(base64)"]
        ]

        let body: [String: Any] = [
            "messages": [
                ["role": "user", "content": messageContent]
            ]
        ]

        guard let url = URL(string: "\(toolkitURL)/agent/chat") else {
            throw ExtractionError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ExtractionError.serverError(statusCode)
        }

        let responseText = try parseResponseText(from: data)
        let extraction = try parseExtractionJSON(from: responseText)
        return buildPuzzle(from: extraction)
    }

    private func parseResponseText(from data: Data) throws -> String {
        if let responseObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = responseObj["text"] as? String {
                return text
            }
            if let choices = responseObj["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
            if let messages = responseObj["messages"] as? [[String: Any]],
               let last = messages.last,
               let content = last["content"] as? String {
                return content
            }
        }

        if let fullText = String(data: data, encoding: .utf8) {
            let lines = fullText.components(separatedBy: "\n")
            var combined = ""
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("0:\"") || trimmed.hasPrefix("d:") || trimmed.hasPrefix("e:") {
                    if trimmed.hasPrefix("0:\"") {
                        let content = String(trimmed.dropFirst(2))
                        if let parsed = try? JSONSerialization.jsonObject(with: Data(content.utf8)) as? String {
                            combined += parsed
                        }
                    }
                    continue
                }
                combined += trimmed
            }
            if !combined.isEmpty { return combined }
            return fullText
        }

        throw ExtractionError.parsingFailed
    }

    private func parseExtractionJSON(from text: String) throws -> ExtractionResponse {
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let jsonStart = jsonString.range(of: "```json") {
            jsonString = String(jsonString[jsonStart.upperBound...])
            if let jsonEnd = jsonString.range(of: "```") {
                jsonString = String(jsonString[..<jsonEnd.lowerBound])
            }
        } else if let jsonStart = jsonString.range(of: "```") {
            jsonString = String(jsonString[jsonStart.upperBound...])
            if let jsonEnd = jsonString.range(of: "```") {
                jsonString = String(jsonString[..<jsonEnd.lowerBound])
            }
        }

        if let braceStart = jsonString.firstIndex(of: "{"),
           let braceEnd = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[braceStart...braceEnd])
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ExtractionError.parsingFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ExtractionResponse.self, from: jsonData)
    }

    private func buildPuzzle(from response: ExtractionResponse) -> Puzzle {
        var activeCells = Set<GridPosition>()
        var cellRegionMap: [GridPosition: String] = [:]
        var regionCells: [String: Set<GridPosition>] = [:]

        for cell in response.cells {
            let pos = GridPosition(row: cell.row, col: cell.col)
            activeCells.insert(pos)
            cellRegionMap[pos] = cell.regionId

            if regionCells[cell.regionId] == nil {
                regionCells[cell.regionId] = []
            }
            regionCells[cell.regionId]?.insert(pos)
        }

        var regions: [Region] = []
        for (index, regionData) in response.regions.enumerated() {
            let constraint: ConstraintType
            switch regionData.constraintType.lowercased() {
            case "sum":
                constraint = .sum(regionData.constraintValue ?? 0)
            case "equal":
                constraint = .equal
            case "notequal", "not_equal", "notEqual":
                constraint = .notEqual
            case "greaterthan", "greater_than", "greaterThan":
                constraint = .greaterThan(regionData.constraintValue ?? 0)
            case "lessthan", "less_than", "lessThan":
                constraint = .lessThan(regionData.constraintValue ?? 0)
            case "any":
                constraint = .any
            default:
                constraint = .none
            }

            let cells = regionCells[regionData.id] ?? []
            regions.append(Region(
                id: regionData.id,
                cells: cells,
                constraint: constraint,
                colorIndex: index
            ))
        }

        var dominoes: [Domino] = []
        for (index, d) in response.dominoes.enumerated() {
            dominoes.append(Domino(
                id: "D\(index)",
                pip1: max(0, min(6, d.pip1)),
                pip2: max(0, min(6, d.pip2))
            ))
        }

        return Puzzle(
            rows: response.rows,
            cols: response.cols,
            activeCells: activeCells,
            cellRegionMap: cellRegionMap,
            regions: regions,
            availableDominoes: dominoes
        )
    }

    private func buildExtractionPrompt() -> String {
        """
        Analyze this screenshot of a NYT Pips domino puzzle game. Extract the puzzle data and return ONLY valid JSON.

        The puzzle has:
        1. A grid of cells in rows/columns. Some cells may be blocked/inactive.
        2. Colored regions - groups of cells sharing the same color, each with a constraint.
        3. Dominoes in a tray at the bottom - each has two halves with 0-6 pip dots.

        Constraint types:
        - A number (e.g. "7") = sum of all pips in region must equal that number → constraintType: "sum"
        - "=" = all pips in region must be same value → constraintType: "equal"
        - "≠" = all pips in region must be different → constraintType: "notEqual"
        - ">N" = sum of pips must be greater than N → constraintType: "greaterThan"
        - "<N" = sum of pips must be less than N → constraintType: "lessThan"
        - "*" or any/star symbol = any value allowed (no restriction but explicitly marked) → constraintType: "any"
        - No symbol = no restriction → constraintType: "none"

        Return JSON in this EXACT format:
        {
          "rows": <number>,
          "cols": <number>,
          "cells": [{"row": 0, "col": 0, "regionId": "R1"}, ...],
          "regions": [{"id": "R1", "constraintType": "sum", "constraintValue": 7}, ...],
          "dominoes": [{"pip1": 0, "pip2": 3}, ...]
        }

        Rules:
        - Only include active/playable cells in "cells". Skip blocked cells.
        - Row/col indices start at 0.
        - Each cell belongs to exactly one region.
        - constraintValue is null for "equal", "notEqual", "any", and "none".
        - List ALL dominoes from the tray.
        - Return ONLY the JSON, no markdown fences, no explanation.
        """
    }
}

nonisolated enum ExtractionError: Error, LocalizedError, Sendable {
    case invalidImage
    case invalidURL
    case serverError(Int)
    case parsingFailed
    case noToolkitURL

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .invalidURL: return "Invalid API URL configuration."
        case .serverError(let code): return "Server error (HTTP \(code))."
        case .parsingFailed: return "Could not parse puzzle data from the image."
        case .noToolkitURL: return "AI service not configured. Set EXPO_PUBLIC_TOOLKIT_URL in project settings."
        }
    }
}
