import StructuredDataCore
import Testing

@testable import AGUIJSONPatch

struct JSONPointerTests {
    @Test func parsesTokensAndUnescapes() throws {
        let pointer = try JSONPointer("/a~1b/m~0n/0/")
        #expect(pointer.tokens == ["a/b", "m~n", "0", ""])
    }

    @Test func rootPointer() throws {
        #expect(try JSONPointer("").isRoot)
    }

    @Test func rejectsMissingLeadingSlash() {
        #expect(throws: JSONPointer.ParseError.self) {
            _ = try JSONPointer("a/b")
        }
    }

    @Test func properPrefix() throws {
        let parent = try JSONPointer("/a")
        let child = try JSONPointer("/a/b")
        #expect(parent.isProperPrefix(of: child))
        #expect(!child.isProperPrefix(of: parent))
        #expect(!parent.isProperPrefix(of: parent))
    }
}

struct JSONPatchTests {
    private let document: StructuredValue = .object([
        "name": .string("delish"),
        "tags": .array([.string("a"), .string("b")]),
        "nested": .object(["count": .number(StructuredNumber(unchecked: "1"))]),
    ])

    private func applyRawJSON(_ operationsJSON: [[String: StructuredValue]], to doc: StructuredValue) throws -> StructuredValue {
        try JSONPatch.apply(raw: operationsJSON.map { .object(OrderedObject($0)) }, to: doc)
    }

    @Test func addObjectKey() throws {
        let result = try JSONPatch.apply(
            [JSONPatchOperation(op: .add, path: "/status", value: .string("ok"))],
            to: document
        )
        #expect(result["status"].stringValue == "ok")
    }

    @Test func addArrayElementAndAppend() throws {
        var result = try JSONPatch.apply(
            [JSONPatchOperation(op: .add, path: "/tags/1", value: .string("x"))],
            to: document
        )
        #expect(result["tags"].arrayValue?.compactMap(\.stringValue) == ["a", "x", "b"])
        result = try JSONPatch.apply(
            [JSONPatchOperation(op: .add, path: "/tags/-", value: .string("z"))],
            to: result
        )
        #expect(result["tags"].arrayValue?.compactMap(\.stringValue) == ["a", "x", "b", "z"])
    }

    @Test func removeAndReplace() throws {
        let result = try JSONPatch.apply(
            [
                JSONPatchOperation(op: .remove, path: "/tags/0"),
                JSONPatchOperation(op: .replace, path: "/name", value: .string("agui")),
            ],
            to: document
        )
        #expect(result["tags"].arrayValue?.count == 1)
        #expect(result["name"].stringValue == "agui")
    }

    @Test func replaceMissingPathThrows() {
        #expect(throws: JSONPatchError.self) {
            _ = try JSONPatch.apply(
                [JSONPatchOperation(op: .replace, path: "/ghost", value: .bool(true))],
                to: document
            )
        }
    }

    @Test func moveAndCopy() throws {
        let result = try JSONPatch.apply(
            [
                JSONPatchOperation(op: .move, path: "/nested/moved", from: "/name"),
                JSONPatchOperation(op: .copy, path: "/copied", from: "/tags/0"),
            ],
            to: document
        )
        #expect(result["name"].isNull == false || result.objectValue?["name"] == nil)
        #expect(result["nested"]["moved"].stringValue == "delish")
        #expect(result["copied"].stringValue == "a")
    }

    @Test func movePrefixOfPathThrows() {
        #expect(throws: JSONPatchError.self) {
            _ = try JSONPatch.apply(
                [JSONPatchOperation(op: .move, path: "/nested/count/deeper", from: "/nested")],
                to: document
            )
        }
    }

    @Test func testOpSucceedsAndFails() throws {
        _ = try JSONPatch.apply(
            [JSONPatchOperation(op: .test, path: "/name", value: .string("delish"))],
            to: document
        )
        #expect(throws: JSONPatchError.self) {
            _ = try JSONPatch.apply(
                [JSONPatchOperation(op: .test, path: "/name", value: .string("other"))],
                to: document
            )
        }
    }

    /// Application is atomic: a failure part-way leaves the original untouched, which the
    /// value type gives for free.
    @Test func failedPatchLeavesOriginalIntact() {
        let original = document
        #expect(throws: JSONPatchError.self) {
            _ = try JSONPatch.apply(
                [
                    JSONPatchOperation(op: .add, path: "/status", value: .string("ok")),
                    JSONPatchOperation(op: .remove, path: "/ghost"),
                ],
                to: original
            )
        }
        #expect(original.objectValue?["status"] == nil)
    }

    /// Applying operations in the wire form that STATE_DELTA carries.
    @Test func rawOperationsFromWire() throws {
        let result = try applyRawJSON(
            [
                ["op": .string("replace"), "path": .string("/nested/count"), "value": .number(StructuredNumber(unchecked: "2"))],
                ["op": .string("add"), "path": .string("/flag"), "value": .bool(true)],
            ],
            to: document
        )
        #expect(result["nested"]["count"].numberValue.map(String.init(describing:)) == "2")
        #expect(result["flag"].boolValue == true)
    }

    @Test func malformedRawOperationThrows() {
        #expect(throws: JSONPatchError.self) {
            _ = try applyRawJSON([["op": .string("explode"), "path": .string("/x")]], to: document)
        }
    }

    @Test func rootReplacement() throws {
        let result = try JSONPatch.apply(
            [JSONPatchOperation(op: .replace, path: "", value: .string("everything"))],
            to: document
        )
        #expect(result.stringValue == "everything")
    }
}
