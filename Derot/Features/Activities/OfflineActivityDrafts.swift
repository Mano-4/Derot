import Foundation
#if canImport(SwiftUI) && canImport(Combine)
import SwiftUI
import Combine
#endif

enum OfflineActivityDraftError: LocalizedError, Equatable {
    case invalidActivityID
    case unsupportedVersion(Int)
    case mismatchedActivity

    var errorDescription: String? {
        switch self {
        case .invalidActivityID:
            return "This activity’s draft could not be identified."
        case .unsupportedVersion:
            return "This draft uses a newer format. The saved file has been kept."
        case .mismatchedActivity:
            return "This draft belongs to a different activity. The saved file has been kept."
        }
    }
}

/// One small, protected file per activity. A draft is separate from a completed entry.
/// The repository has no network, account, UI, or in-memory source of truth.
struct OfflineActivityDraftRepository {
    let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
            self.directoryURL = support
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "BreathingExercise", isDirectory: true)
                .appendingPathComponent("ActivityDrafts", isDirectory: true)
        }
    }

    func fileURL(activityID: String) throws -> URL {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !activityID.isEmpty, activityID.utf8.count <= 80,
              activityID.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw OfflineActivityDraftError.invalidActivityID
        }
        return directoryURL.appendingPathComponent(activityID + ".json", isDirectory: false)
    }

    func read<Payload: Codable>(_ type: Payload.Type, activityID: String) throws -> Payload? {
        let url = try fileURL(activityID: activityID)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError
            where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
        let decoder = JSONDecoder()
        let header = try decoder.decode(VersionHeader.self, from: data)
        guard header.version == 1 else {
            throw OfflineActivityDraftError.unsupportedVersion(header.version)
        }
        let document = try decoder.decode(Document<Payload>.self, from: data)
        guard document.activityID == activityID else {
            throw OfflineActivityDraftError.mismatchedActivity
        }
        return document.payload
    }

    func write<Payload: Codable>(_ payload: Payload, activityID: String) throws {
        let url = try fileURL(activityID: activityID)
        // A failed read must never turn into an overwrite of the person's old words.
        let _: Payload? = try read(Payload.self, activityID: activityID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(version: 1, activityID: activityID, payload: payload))
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    /// An empty editor may clear only a readable draft of its own payload type.
    /// Failed restores therefore cannot silently erase an unknown or newer file.
    func removeReadable<Payload: Codable>(_ type: Payload.Type, activityID: String) throws {
        let _: Payload? = try read(type, activityID: activityID)
        try remove(activityID: activityID)
    }

    /// Only call after an explicit discard or a completed activity.
    func remove(activityID: String) throws {
        let url = try fileURL(activityID: activityID)
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError
            where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return
        }
    }

    private struct VersionHeader: Decodable {
        let version: Int
    }

    private struct Document<Payload: Codable>: Codable {
        let version: Int
        let activityID: String
        let payload: Payload
    }
}

#if canImport(SwiftUI) && canImport(Combine)
private struct ActivityDraftHostArchivesKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The library removes the recovery copy only after the completed journal write succeeds.
    var activityDraftHostArchives: Bool {
        get { self[ActivityDraftHostArchivesKey.self] }
        set { self[ActivityDraftHostArchivesKey.self] = newValue }
    }
}

enum ActivityDraftExitAction {
    case saveAndClose
    case discardAndClose
    case complete

    var retryTitle: String {
        switch self {
        case .saveAndClose: return "Try closing again"
        case .discardAndClose: return "Try discarding again"
        case .complete: return "Try finishing again"
        }
    }
}

/// Views choose when to restore/save. No subscription silently resets an active editor.
@MainActor
final class ActivityDraftStore<Payload: Codable>: ObservableObject {
    @Published private(set) var hasDraft = false
    @Published private(set) var errorMessage: String?

    private let activityID: String
    private let repository: OfflineActivityDraftRepository
    private var didRestore = false
    private var restoredPayload: Payload?
    private var pendingOperation: PendingOperation?

    private enum PendingOperation {
        case restore
        case save(Payload)
        case clearEmpty
        case discard
    }

    init(activityID: String, repository: OfflineActivityDraftRepository = OfflineActivityDraftRepository()) {
        self.activityID = activityID
        self.repository = repository
    }

    /// Reads once; repeated calls return the same cached snapshot until a successful save.
    func restore() -> Payload? {
        guard !didRestore else { return restoredPayload }
        didRestore = true
        return readDraft()
    }

    @discardableResult
    func save(_ payload: Payload) -> Bool {
        do {
            try repository.write(payload, activityID: activityID)
            restoredPayload = payload
            didRestore = true
            hasDraft = true
            errorMessage = nil
            pendingOperation = nil
            return true
        } catch {
            pendingOperation = .save(payload)
            errorMessage = "Your draft hasn’t saved yet. Try again before leaving."
            return false
        }
    }

    /// Clearing all fields is an edit, not permission to delete an unreadable file.
    @discardableResult
    func clearEmptyDraft() -> Bool {
        do {
            try repository.removeReadable(Payload.self, activityID: activityID)
            restoredPayload = nil
            hasDraft = false
            didRestore = true
            errorMessage = nil
            pendingOperation = nil
            return true
        } catch {
            pendingOperation = .clearEmpty
            errorMessage = "Your saved draft couldn’t be updated. Its file has been kept on this device."
            return false
        }
    }

    @discardableResult
    func discard() -> Bool {
        do {
            try repository.remove(activityID: activityID)
            restoredPayload = nil
            hasDraft = false
            didRestore = true
            errorMessage = nil
            pendingOperation = nil
            return true
        } catch {
            pendingOperation = .discard
            errorMessage = "Your draft couldn’t be removed. Please try again."
            return false
        }
    }

    func retryLastOperation() {
        guard let operation = pendingOperation else { return }
        switch operation {
        case .restore:
            _ = readDraft()
        case .save(let payload):
            _ = save(payload)
        case .clearEmpty:
            _ = clearEmptyDraft()
        case .discard:
            _ = discard()
        }
    }

    private func readDraft() -> Payload? {
        do {
            let payload = try repository.read(Payload.self, activityID: activityID)
            restoredPayload = payload
            hasDraft = payload != nil
            errorMessage = nil
            pendingOperation = nil
            return payload
        } catch {
            pendingOperation = .restore
            errorMessage = "Your saved draft couldn’t be opened. Its file has been kept on this device."
            return nil
        }
    }
}

/// Quiet on success; failures stay visible until the actual disk operation succeeds.
@MainActor
struct ActivityDraftNotice<Payload: Codable>: View {
    @ObservedObject var store: ActivityDraftStore<Payload>
    var retryTitle: String = "Try again"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        if let message = store.errorMessage {
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Button(retryTitle) {
                    if let onRetry {
                        onRetry()
                    } else {
                        store.retryLastOperation()
                    }
                }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#endif
