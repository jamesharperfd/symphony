import Foundation
import Yams

public enum WorkflowLoaderError: Error, Equatable {
    case missingFile(String)
    case invalidFrontMatter
}

public struct WorkflowLoader {
    public init() {}

    public func load(path: String? = nil) throws -> WorkflowDefinition {
        let resolvedPath = resolvePath(from: path)

        guard FileManager.default.isReadableFile(atPath: resolvedPath) else {
            throw WorkflowLoaderError.missingFile(resolvedPath)
        }

        let contents: String
        do {
            contents = try String(contentsOfFile: resolvedPath, encoding: .utf8)
        } catch {
            throw WorkflowLoaderError.missingFile(resolvedPath)
        }

        let parsed = try parse(contents: contents)
        return WorkflowDefinition(
            config: parsed.config,
            prompt_template: parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func resolvePath(from path: String?) -> String {
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("WORKFLOW.md")
                .path
        }

        return path
    }

    private func parse(contents: String) throws -> (config: [String: Any], body: String) {
        guard contents.hasPrefix("---\n") || contents == "---" else {
            return ([:], contents)
        }

        let lines = contents.components(separatedBy: .newlines)
        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            throw WorkflowLoaderError.invalidFrontMatter
        }

        let yaml = lines[1..<closingIndex].joined(separator: "\n")
        let body = Array(lines[(closingIndex + 1)...]).joined(separator: "\n")
        let loadedYaml = try Yams.load(yaml: yaml)

        if loadedYaml == nil {
            return ([:], body)
        }

        guard let mapping = loadedYaml as? [String: Any] else {
            if let genericMap = loadedYaml as? [AnyHashable: Any] {
                var stringKeyedMap: [String: Any] = [:]

                for (key, value) in genericMap {
                    guard let stringKey = key as? String else {
                        throw WorkflowLoaderError.invalidFrontMatter
                    }
                    stringKeyedMap[stringKey] = value
                }

                return (stringKeyedMap, body)
            }

            throw WorkflowLoaderError.invalidFrontMatter
        }

        return (mapping, body)
    }
}
