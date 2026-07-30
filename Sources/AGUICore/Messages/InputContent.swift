import StructuredDataCore

/// マルチモーダル入力の実体の所在。
public enum InputContentSource: Sendable, Equatable {
    /// インラインデータ(base64 等)。
    case data(value: String, mimeType: String)
    /// 参照 URL。
    case url(value: String, mimeType: String?)
}

extension InputContentSource: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case mimeType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "data":
            self = try .data(
                value: container.decode(String.self, forKey: .value),
                mimeType: container.decode(String.self, forKey: .mimeType)
            )
        case "url":
            self = try .url(
                value: container.decode(String.self, forKey: .value),
                mimeType: container.decodeIfPresent(String.self, forKey: .mimeType)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown InputContentSource type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .data(let value, let mimeType):
            try container.encode("data", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(mimeType, forKey: .mimeType)
        case .url(let value, let mimeType):
            try container.encode("url", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encodeIfPresent(mimeType, forKey: .mimeType)
        }
    }
}

/// メディア入力(image / audio / video / document 共通のペイロード)。
public struct MediaInputContent: Codable, Sendable, Equatable {
    public var source: InputContentSource
    public var metadata: StructuredValue?

    public init(source: InputContentSource, metadata: StructuredValue? = nil) {
        self.source = source
        self.metadata = metadata
    }
}

/// user メッセージのマルチモーダルコンテンツパート。
///
/// ミラー元: `@ag-ui/core` `types.ts` の `InputContentSchema`。
/// 上流のレガシー `binary` 形(typed 形へ移行済み)は実装しない。
public enum InputContent: Sendable, Equatable {
    case text(String)
    case image(MediaInputContent)
    case audio(MediaInputContent)
    case video(MediaInputContent)
    case document(MediaInputContent)
}

extension InputContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = try .text(container.decode(String.self, forKey: .text))
        case "image":
            self = try .image(MediaInputContent(from: decoder))
        case "audio":
            self = try .audio(MediaInputContent(from: decoder))
        case "video":
            self = try .video(MediaInputContent(from: decoder))
        case "document":
            self = try .document(MediaInputContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown InputContent type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let media):
            try container.encode("image", forKey: .type)
            try media.encode(to: encoder)
        case .audio(let media):
            try container.encode("audio", forKey: .type)
            try media.encode(to: encoder)
        case .video(let media):
            try container.encode("video", forKey: .type)
            try media.encode(to: encoder)
        case .document(let media):
            try container.encode("document", forKey: .type)
            try media.encode(to: encoder)
        }
    }
}
