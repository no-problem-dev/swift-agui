/// ツールコールの種別(現仕様では "function" のみ)。
public enum ToolCallKind: String, Codable, Sendable {
    case function
}

/// LLM の関数呼び出し。`arguments` は JSON 文字列。
public struct AGUIFunctionCall: Codable, Sendable, Equatable {
    public var name: String
    public var arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// assistant メッセージに載るツールコール。
public struct AGUIToolCall: Codable, Sendable, Equatable {
    public var id: String
    public var type: ToolCallKind
    public var function: AGUIFunctionCall
    /// ゼロデータ保持モードの暗号化推論値(REASONING_ENCRYPTED_VALUE で届く)。
    public var encryptedValue: String?

    public init(
        id: String,
        type: ToolCallKind = .function,
        function: AGUIFunctionCall,
        encryptedValue: String? = nil
    ) {
        self.id = id
        self.type = type
        self.function = function
        self.encryptedValue = encryptedValue
    }
}
