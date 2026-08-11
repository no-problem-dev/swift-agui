import StructuredDataCore

/// Where the bytes of a multimodal input actually live, discriminated on the wire by
/// `type` being `"data"` or `"url"`; anything else fails to decode.
public enum InputContentSource: Sendable, Equatable {
    /// Bytes inline, typically base64. `mimeType` is required in this form.
    case data(value: String, mimeType: String)
    /// A URL the agent has to fetch itself, with `mimeType` optional because the
    /// response may declare it.
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

/// The payload shared by the image, audio, video, and document parts — they differ only
/// in the `type` discriminator that sits alongside it, not in shape.
public struct MediaInputContent: Codable, Sendable, Equatable {
    public var source: InputContentSource
    public var metadata: StructuredValue?

    public init(source: InputContentSource, metadata: StructuredValue? = nil) {
        self.source = source
        self.metadata = metadata
    }
}

/// One part of a user message's multimodal content, discriminated by `type`.
///
/// Mirrors `InputContentSchema` in `@ag-ui/core` `types.ts`. The upstream legacy
/// `binary` form, superseded by these typed parts, is not implemented: a message
/// still carrying one fails to decode rather than losing the part silently.
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
