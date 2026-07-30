import StructuredDataCore

/// `RUN_STARTED`。run(1 ターンの実行)の開始。
public struct RunStartedEvent: Codable, Sendable, Equatable {
    public var threadId: String
    public var runId: String
    public var parentRunId: String?
    /// サーバーが正準の入力を再生/注入するための任意フィールド。
    public var input: RunAgentInput?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        threadId: String,
        runId: String,
        parentRunId: String? = nil,
        input: RunAgentInput? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.threadId = threadId
        self.runId = runId
        self.parentRunId = parentRunId
        self.input = input
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `RUN_FINISHED` の帰結。省略(レガシー producer)は正常完了として扱う。
public enum RunFinishedOutcome: Sendable, Equatable {
    case success
    /// 人間の入力を待つ割り込み。run はここで終了し、クライアントは次の run の
    /// `RunAgentInput.resume` で全 interrupt に応答する。非空が仕様上の不変条件。
    case interrupt([Interrupt])
}

extension RunFinishedOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case interrupts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "success":
            self = .success
        case "interrupt":
            let interrupts = try container.decode([Interrupt].self, forKey: .interrupts)
            guard !interrupts.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .interrupts,
                    in: container,
                    debugDescription: "interrupt outcome requires at least one interrupt"
                )
            }
            self = .interrupt(interrupts)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown RunFinishedOutcome type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success:
            try container.encode("success", forKey: .type)
        case .interrupt(let interrupts):
            try container.encode("interrupt", forKey: .type)
            try container.encode(interrupts, forKey: .interrupts)
        }
    }
}

/// `RUN_FINISHED`。run の終了(成功または割り込み)。
///
/// `result` は後方互換のためイベントのルートに残る(`outcome` の中ではない)。
/// `outcome: null` は省略として受理する(Python SDK が emit する実績があるため)。
public struct RunFinishedEvent: Codable, Sendable, Equatable {
    public var threadId: String
    public var runId: String
    public var result: StructuredValue?
    public var outcome: RunFinishedOutcome?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        threadId: String,
        runId: String,
        result: StructuredValue? = nil,
        outcome: RunFinishedOutcome? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.threadId = threadId
        self.runId = runId
        self.result = result
        self.outcome = outcome
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `RUN_ERROR`。run の異常終了。以後このストリームにイベントは流れない。
public struct RunErrorEvent: Codable, Sendable, Equatable {
    public var message: String
    public var code: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        message: String,
        code: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.message = message
        self.code = code
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `STEP_STARTED`。名前付きステップの開始(ネスト不可)。
public struct StepStartedEvent: Codable, Sendable, Equatable {
    public var stepName: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(stepName: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.stepName = stepName
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `STEP_FINISHED`。名前付きステップの終了。
public struct StepFinishedEvent: Codable, Sendable, Equatable {
    public var stepName: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(stepName: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.stepName = stepName
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
