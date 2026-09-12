//
//  JSONHistoryStore.swift
//  Jokoson
//

import CoreData
import Foundation

enum JSONHistorySource: String, Sendable {
    case paste
    case file
    case manual
}

enum JSONHistoryColor: String, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, blue, purple, gray

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct JSONHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let sourceText: String
    let title: String
    let color: JSONHistoryColor?
    let source: JSONHistorySource
    let createdAt: Date
}

@objc(JSONHistoryItem)
final class JSONHistoryItem: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var sourceText: String
    @NSManaged var title: String
    @NSManaged var color: String?
    @NSManaged var source: String
    @NSManaged var createdAt: Date
}

@MainActor
final class JSONHistoryStore {
    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "JokosonHistory", managedObjectModel: Self.managedObjectModel)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Could not load JSON history: \(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        removeDuplicates()
    }

    var entries: [JSONHistoryEntry] {
        let request = NSFetchRequest<JSONHistoryItem>(entityName: "JSONHistoryItem")
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(JSONHistoryItem.createdAt), ascending: false)]
        return (try? container.viewContext.fetch(request))?.map(Self.entry(from:)) ?? []
    }

    func add(sourceText: String, source: JSONHistorySource) -> JSONHistoryEntry? {
        let createdAt = Date()
        if let item = item(withSourceText: sourceText) {
            item.source = source.rawValue
            item.createdAt = createdAt
            guard save() else { return nil }
            return Self.entry(from: item)
        }

        let item = JSONHistoryItem(context: container.viewContext)
        item.id = UUID()
        item.sourceText = sourceText
        item.title = "Untitled JSON \(createdAt.formatted(date: .abbreviated, time: .shortened))"
        item.source = source.rawValue
        item.createdAt = createdAt
        guard save() else { return nil }
        return Self.entry(from: item)
    }

    func rename(_ id: UUID, to title: String) {
        guard let item = item(with: id) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        _ = save()
    }

    func setColor(_ color: JSONHistoryColor?, for id: UUID) {
        guard let item = item(with: id) else { return }
        item.color = color?.rawValue
        _ = save()
    }

    func delete(_ id: UUID) {
        guard let item = item(with: id) else { return }
        container.viewContext.delete(item)
        _ = save()
    }

    func clear() {
        entries.forEach { delete($0.id) }
    }

    private func item(with id: UUID) -> JSONHistoryItem? {
        let request = NSFetchRequest<JSONHistoryItem>(entityName: "JSONHistoryItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? container.viewContext.fetch(request).first
    }

    private func item(withSourceText sourceText: String) -> JSONHistoryItem? {
        let request = NSFetchRequest<JSONHistoryItem>(entityName: "JSONHistoryItem")
        request.predicate = NSPredicate(format: "sourceText == %@", sourceText)
        request.fetchLimit = 1
        return try? container.viewContext.fetch(request).first
    }

    private func removeDuplicates() {
        let request = NSFetchRequest<JSONHistoryItem>(entityName: "JSONHistoryItem")
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(JSONHistoryItem.createdAt), ascending: false)]
        guard let items = try? container.viewContext.fetch(request) else { return }
        var seen = Set<String>()
        for item in items where !seen.insert(item.sourceText).inserted {
            container.viewContext.delete(item)
        }
        _ = save()
    }

    @discardableResult
    private func save() -> Bool {
        guard container.viewContext.hasChanges else { return true }
        do {
            try container.viewContext.save()
            return true
        } catch {
            container.viewContext.rollback()
            assertionFailure("Could not save JSON history: \(error.localizedDescription)")
            return false
        }
    }

    private static func entry(from item: JSONHistoryItem) -> JSONHistoryEntry {
        JSONHistoryEntry(
            id: item.id,
            sourceText: item.sourceText,
            title: item.title,
            color: item.color.flatMap(JSONHistoryColor.init(rawValue:)),
            source: JSONHistorySource(rawValue: item.source) ?? .paste,
            createdAt: item.createdAt
        )
    }

    private static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "JSONHistoryItem"
        entity.managedObjectClassName = NSStringFromClass(JSONHistoryItem.self)
        entity.properties = [
            attribute("id", type: .UUIDAttributeType, optional: false),
            attribute("sourceText", type: .stringAttributeType, optional: false),
            attribute("title", type: .stringAttributeType, optional: false),
            attribute("color", type: .stringAttributeType, optional: true),
            attribute("source", type: .stringAttributeType, optional: false),
            attribute("createdAt", type: .dateAttributeType, optional: false)
        ]
        model.entities = [entity]
        return model
    }()

    private static func attribute(_ name: String, type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
