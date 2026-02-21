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

        VISUAL FORMAT OF THE PUZZLE:
        - The grid is shown as a collection of rounded square cells arranged in rows and columns.
        - Cells belonging to the same region share the same background color (e.g. purple, pink, teal, orange, olive, gray, etc.) and are grouped by dashed colored borders.
        - BLOCKED/INACTIVE cells appear as solid BLACK rectangles. These are NOT part of any region. Do NOT include them.
        - Constraint badges appear as small colored DIAMOND shapes (rotated squares) positioned at the edge or corner of a region. Inside each diamond is the constraint value:
          • A number like "0", "7", "12" → sum constraint (all pips in region must sum to that number)
          • "=" symbol → equal constraint (all pips in region must be the same value)
          • "≠" symbol → notEqual constraint (all pips must be different)
          • ">N" → greaterThan constraint
          • "<N" → lessThan constraint
          • No diamond badge on the region → "any" constraint (no restriction)
        - The domino tray at the bottom shows dominoes as white rectangular tiles, each split into two halves with pip dots (0-6 dots per half).

        GRID ANALYSIS:
        1. First determine the bounding grid dimensions (rows × cols) by looking at the full extent of the grid including blocked cells.
        2. Identify which cells are active (colored) vs blocked (black). Only include active cells.
        3. Group active cells by their background color to determine regions.
        4. Find the constraint diamond badge for each region and read its value.
        5. Count all dominoes in the tray carefully - count the pip dots on each half.

        Return JSON in this EXACT format:
        {
          "rows": <number>,
          "cols": <number>,
          "cells": [{"row": 0, "col": 0, "regionId": "R1"}, ...],
          "regions": [{"id": "R1", "constraintType": "sum", "constraintValue": 7}, ...],
          "dominoes": [{"pip1": 0, "pip2": 3}, ...]
        }

        Rules:
        - Only include active/playable cells (colored cells). Skip all black/blocked cells.
        - Row/col indices start at 0, counting from top-left of the bounding grid.
        - Each active cell belongs to exactly one region (determined by its background color).
        - constraintType must be one of: "sum", "equal", "notEqual", "greaterThan", "lessThan", "any".
        - constraintValue is the number for "sum"/"greaterThan"/"lessThan", null for others.
        - If a region has NO diamond badge, use constraintType: "any" with constraintValue: null.
        - List ALL dominoes from the tray. Count pip dots carefully: 0=blank, 1=one dot center, 2=diagonal dots, 3=diagonal three, 4=four corners, 5=four corners+center, 6=six dots.
        - For each domino, pip1 is the LEFT half, pip2 is the RIGHT half.
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
