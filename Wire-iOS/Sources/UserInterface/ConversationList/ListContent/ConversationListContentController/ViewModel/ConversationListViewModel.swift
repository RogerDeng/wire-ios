
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import DifferenceKit

// Placeholder for conversation requests item
///TODO: create a protocol, shared with ZMConversation
@objc
final class ConversationListConnectRequestsItem : NSObject {}

final class ConversationListViewModel: NSObject {
    
    typealias SectionIdentifier = String
    
    fileprivate enum ListItem: Equatable, Differentiable {
        case pendingConnection
        case favorite(ZMConversation)
        case conversation(ZMConversation)
        
        
        func isContentEqual(to source: ConversationListViewModel.ListItem) -> Bool {
            return self == source
        }
        
        var differenceIdentifier: String {
            switch self {
            case .pendingConnection:
                return "pendingConnection"
            case .favorite(let conversation):
                return conversation.nonpersistedObjectIdentifer + "_favorite"
            case .conversation(let conversation):
                return conversation.nonpersistedObjectIdentifer
            }
        }
        
        static func == (lhs: ConversationListViewModel.ListItem, rhs: ConversationListViewModel.ListItem) -> Bool {
            switch (lhs, rhs) {
            case (.pendingConnection, .pendingConnection):
                return true
            case (.favorite(let lhsConversation), .favorite(let rhsConversation)):
                return lhsConversation === rhsConversation
            case (.conversation(let lhsConversation), .conversation(let rhsConversation)):
                return lhsConversation === rhsConversation
            default:
                return false
            }
        }
    }

    fileprivate struct Section: DifferentiableSection {
        
        enum Kind: Equatable, Hashable {

            /// for incoming requests
            case contactRequests

            /// for self pending requests / conversations
            case conversations

            /// one to one conversations
            case contacts

            /// group conversations
            case groups

            /// favorites
            case favorites

            /// conversations in folders
            case folder(label: LabelType)

            func hash(into hasher: inout Hasher) {
                hasher.combine(identifier)
            }
            
            var identifier: SectionIdentifier {
                switch self {
                case.folder(label: let label):
                    return label.remoteIdentifier?.transportString() ?? "folder"
                default:
                    return canonicalName
                }
            }
            
            var canonicalName: String {
                switch self {
                case .contactRequests:
                    return "contactRequests"
                case .conversations:
                    return "conversations"
                case .contacts:
                    return "contacts"
                case .groups:
                    return "groups"
                case .favorites:
                    return "favorites"
                case .folder(label: let label):
                    return label.name ?? "folder"
                }
            }
            
            var localizedName: String? {
                switch self {
                case .conversations:
                    return nil
                case .contactRequests:
                    return "list.section.requests".localized
                case .contacts:
                    return "list.section.contacts".localized
                case .groups:
                    return "list.section.groups".localized
                case .favorites:
                    return "list.section.favorites".localized
                case .folder(label: let label):
                    return label.name
                }
            }
            
            static func == (lhs: ConversationListViewModel.Section.Kind, rhs: ConversationListViewModel.Section.Kind) -> Bool {
                switch (lhs, rhs) {
                case (.conversations, .conversations):
                    fallthrough
                case (.contactRequests, .contactRequests):
                    fallthrough
                case (.contacts, .contacts):
                    fallthrough
                case (.groups, .groups):
                    fallthrough
                case (.favorites, .favorites):
                    return true
                case (.folder(let lhsLabel), .folder(let rhsLabel)):
                    return lhsLabel === rhsLabel
                default:
                    return false
                }
            }
        }
        
        var kind: Kind
        var collapsed: Bool
        var allElements: [ListItem]
        
        var elements: [ListItem] {
            if case .contactRequests = kind {
                return allElements.isEmpty ? [] : [ListItem.pendingConnection]
            } else {
                return collapsed ? [] : allElements
            }
        }
    
        /// ref to AggregateArray, we return the first found item's index
        ///
        /// - Parameter item: item to search
        /// - Returns: the index of the item
        func index(for item: ListItem) -> Int? {
            return elements.firstIndex(of: item)
        }
        
        var differenceIdentifier: String {
            return kind.identifier
        }
        
        func isContentEqual(to source: ConversationListViewModel.Section) -> Bool {
            return kind == source.kind
        }
        
        init<C: Collection>(source: Section, elements: C) where C.Element == ListItem {
            self.kind = source.kind
            self.collapsed = source.collapsed
            self.allElements = Array(elements)
        }

        init(kind: Kind, conversationDirectory: ConversationDirectoryType, collapsed: Bool) {
            self.kind = kind
            self.collapsed = collapsed
            
            let conversationListType: ConversationListType
            switch kind {
            case .contactRequests:
                conversationListType = .pending
            case .conversations:
                conversationListType = .unarchived
            case .contacts:
                conversationListType = .contacts
            case .groups:
                conversationListType = .groups
            case .favorites:
                conversationListType = .favorites
            case .folder(label: let label):
                conversationListType = .folder(label)
            }
            
            self.allElements = conversationDirectory.conversations(by: conversationListType).map {
                if kind == .favorites {
                    return .favorite($0)
                } else {
                    return .conversation($0)
                }
            }
        }
    }

    @objc
    static let contactRequestsItem: ConversationListConnectRequestsItem = ConversationListConnectRequestsItem()

    /// current selected ZMConversaton or ConversationListConnectRequestsItem object
    ///TODO: create protocol of these 2 classes
    @objc
    private(set) var selectedItem: AnyHashable? {
        didSet {
            /// expand the section if selcted item is update
            guard selectedItem != oldValue,
                  let indexPath = self.indexPath(for: selectedItem),
                  collapsed(at: indexPath.section) else { return }

            setCollapsed(sectionIndex: indexPath.section, collapsed: false, batchUpdate: false)
        }
    }

    @objc
    weak var delegate: ConversationListViewModelDelegate?
    weak var restorationDelegate: ConversationListViewModelRestorationDelegate? {
        didSet {
            restorationDelegate?.listViewModel(self, didRestoreFolderEnabled: folderEnabled)
        }
    }
    weak var stateDelegate: ConversationListViewModelStateDelegate? {
        didSet {
            delegateFolderEnableState(newState: state)
        }
    }

    private weak var selfUserObserver: NSObjectProtocol?

    var folderEnabled: Bool {
        set {
            guard newValue != state.folderEnabled else { return }

            state.folderEnabled = newValue
            sections = _createSections()
            delegate?.listViewModelShouldBeReloaded()
            

            delegateFolderEnableState(newState: state)
        }
        
        get {
            return state.folderEnabled
        }
    }

    // Local copies of the lists.
    private var sections: [Section] = []

    private typealias DiffKitSection = ArraySection<Int, SectionItem>

    /// make items has different hash in different sections
    private struct SectionItem: Hashable, Differentiable {
        let item: AnyHashable
        let section: Section.Kind
    }

    /// for folder enabled and collapse presistent
    private lazy var _state: State = {
        guard let persistentPath = ConversationListViewModel.persistentURL,
            let jsonData = try? Data(contentsOf: persistentPath) else { return State()
        }

        do {
            return try JSONDecoder().decode(ConversationListViewModel.State.self, from: jsonData)
        } catch {
            log.error("restore state error: \(error)")
            return State()
        }
    }()

    private var state: State {
        get {
            return _state
        }

        set {
            /// simulate willSet

            /// assign
            if newValue != _state {
                _state = newValue
            }

            /// simulate didSet
            saveState(state: _state)
        }
    }

    private var conversationDirectoryToken: Any?

    private let userSession: UserSessionSwiftInterface?

    init(userSession: UserSessionSwiftInterface? = ZMUserSession.shared()) {
        self.userSession = userSession

        super.init()

        setupObservers()
        folderEnabled = state.folderEnabled
        sections = _createSections()
    }

    private func delegateFolderEnableState(newState: State) {
        stateDelegate?.listViewModel(self, didChangeFolderEnabled: folderEnabled)
    }

    private func setupObservers() {
        conversationDirectoryToken = userSession?.conversationDirectory.addObserver(self)
    }

    func sectionHeaderTitle(sectionIndex: Int) -> String? {
        return kind(of: sectionIndex)?.localizedName
    }

    /// return true if seaction header is visible.
    /// For .contactRequests section it is always invisible
    /// When folderEnabled == true, returns false
    ///
    /// - Parameter sectionIndex: section number of collection view
    /// - Returns: if the section exists and visible, return true. 
    func sectionHeaderVisible(section: Int) -> Bool {
        guard sections.indices.contains(section),
              kind(of: section) != .contactRequests,
              folderEnabled else { return false }

        return !sections[section].allElements.isEmpty
    }


    private func kind(of sectionIndex: Int) -> Section.Kind? {
        guard sections.indices.contains(sectionIndex) else { return nil }

        return sections[sectionIndex].kind
    }


    /// Section's canonical name
    ///
    /// - Parameter sectionIndex: section index of the collection view
    /// - Returns: canonical name
    func sectionCanonicalName(of sectionIndex: Int) -> String? {
        guard sectionIndex < sectionCount else { return nil }
        
        return sections[sectionIndex].kind.canonicalName
    }

    @objc
    var sectionCount: UInt {
        return UInt(sections.count)
    }

    @objc
    func numberOfItems(inSection sectionIndex: Int) -> Int {
        guard sectionIndex < sectionCount else { return 0 }

        return sections[sectionIndex].elements.count
    }

    ///TODO: convert all UInt to Int
    @objc(sectionAtIndex:)
    func section(at sectionIndex: UInt) -> [AnyHashable]? {
        if sectionIndex >= sectionCount {
            return nil
        }

        return sections[Int(sectionIndex)].elements.map {
            switch $0 {
            case .pendingConnection:
                return ConversationListViewModel.contactRequestsItem
            case .favorite(let conversation):
                return conversation
            case .conversation(let conversation):
                return conversation
            }
        }
    }

    @objc(itemForIndexPath:)
    func item(for indexPath: IndexPath) -> AnyHashable? {
        guard let items = section(at: UInt(indexPath.section)),
              items.indices.contains(indexPath.item) else { return nil }
        
        return items[indexPath.item]
    }

    ///TODO: Question: we may have multiple items in folders now. return array of IndexPaths?
    @objc(indexPathForItem:)
    func indexPath(for item: AnyHashable?) -> IndexPath? {
        guard let item = item else { return nil } 

        for (sectionIndex, section) in sections.enumerated() {
            if let index = section.index(for: .conversation(item as! ZMConversation) ) {
                return IndexPath(item: index, section: sectionIndex)
            }
        }

        return nil
    }

    private func reload() {
        sections = _createSections()
        delegate?.listViewModelShouldBeReloaded()
    }

    /// Select the item at an index path
    ///
    /// - Parameter indexPath: indexPath of the item to select
    /// - Returns: the item selected
    @objc(selectItemAtIndexPath:)
    @discardableResult
    func selectItem(at indexPath: IndexPath) -> AnyHashable? {
        let item = self.item(for: indexPath)
        select(itemToSelect: item)
        return item
    }


    /// Search for next items
    ///
    /// - Parameters:
    ///   - index: index of search item
    ///   - sectionIndex: section of search item
    /// - Returns: an index path for next existing item
    @objc(itemAfterIndex:section:)
    func item(after index: Int, section sectionIndex: UInt) -> IndexPath? {
        guard let section = self.section(at: sectionIndex) else { return nil }

        if section.count > index + 1 {
            // Select next item in section
            return IndexPath(item: index + 1, section: Int(sectionIndex))
        } else if index + 1 >= section.count {
            // select last item in previous section
            return firstItemInSection(after: sectionIndex)
        }

        return nil
    }

    private func firstItemInSection(after sectionIndex: UInt) -> IndexPath? {
        let nextSectionIndex = sectionIndex + 1

        if nextSectionIndex >= sectionCount {
            // we are at the end, so return nil
            return nil
        }

        if let section = self.section(at: nextSectionIndex) {
            if section.isEmpty {
                // Recursively move forward
                return firstItemInSection(after: nextSectionIndex)
            } else {
                return IndexPath(item: 0, section: Int(nextSectionIndex))
            }
        }

        return nil
    }


    /// Search for previous items
    ///
    /// - Parameters:
    ///   - index: index of search item
    ///   - sectionIndex: section of search item
    /// - Returns: an index path for previous existing item
    @objc(itemPreviousToIndex:section:)
    func itemPrevious(to index: Int, section sectionIndex: UInt) -> IndexPath? {
        guard let section = self.section(at: sectionIndex) else { return nil }

        if section.indices.contains(index - 1) {
            // Select previous item in section
            return IndexPath(item: index - 1, section: Int(sectionIndex))
        } else if index == 0 {
            // select last item in previous section
            return lastItemInSectionPrevious(to: Int(sectionIndex))
        }

        return nil
    }

    func lastItemInSectionPrevious(to sectionIndex: Int) -> IndexPath? {
        let previousSectionIndex = sectionIndex - 1

        if previousSectionIndex < 0 {
            // we are at the top, so return nil
            return nil
        }

        guard let section = self.section(at: UInt(previousSectionIndex)) else { return nil }

        if section.isEmpty {
            // Recursively move back
            return lastItemInSectionPrevious(to: previousSectionIndex)
        } else {
            return IndexPath(item: section.count - 1, section: Int(previousSectionIndex))
        }
    }
    
    private func _createSections() -> [Section] {
        guard let conversationDirectory = userSession?.conversationDirectory else { return [] }
        
        var kinds: [Section.Kind]
        if folderEnabled {
            kinds = [.contactRequests,
                     .favorites,
                     .groups,
                     .contacts]
            
            let folders: [Section.Kind] = conversationDirectory.allFolders.map({ .folder(label: $0) })
            kinds.append(contentsOf: folders)
        } else {
            kinds = [.contactRequests,
                     .conversations]
        }
        
        let sections = kinds.map{ Section(kind: $0, conversationDirectory: conversationDirectory, collapsed: state.collapsed.contains($0.identifier)) }
        
        return sections.filter({ !$0.allElements.isEmpty })
    }
    
    private func sectionItems(for kind: Section.Kind) -> [AnyHashable]? {
        for section in sections {
            if section.kind == kind {
                return section.elements.map({
                    switch $0 {
                    case .pendingConnection:
                        return ConversationListViewModel.contactRequestsItem
                    case .favorite(let conversation):
                        return conversation
                    case .conversation(let conversation):
                        return conversation
                    }
                })
            }
        }

        return nil
    }

    @discardableResult
    private func updateForConversationType(kind: Section.Kind) -> Bool {
        guard let conversationDirectory = userSession?.conversationDirectory else { return false }

        var target: [Section]
        if let index = sections.firstIndex(where: { $0.kind == kind }) {
            target = sections
            target[index] = Section(kind: kind, conversationDirectory: conversationDirectory, collapsed: state.collapsed.contains(kind.identifier))
        } else {
            target = _createSections()
        }
        
        foo(target: target.filter({ !$0.allElements.isEmpty }))

        return true
    }
    
    private func foo(target: [Section]) {
        let target = target.filter({ !$0.allElements.isEmpty })
        
        let changeset = StagedChangeset(source: sections, target: target)
        
        stateDelegate?.reload(using: changeset, interrupt: { _ in
            return false
        }) { data in
            sections = data
        }
    }
    
    @objc(selectItem:)
    @discardableResult
    func select(itemToSelect: AnyHashable?) -> Bool {
        guard let itemToSelect = itemToSelect else {
            internalSelect(itemToSelect: nil)
            return false
        }

        if indexPath(for: itemToSelect) == nil {
            guard let conversation = itemToSelect as? ZMConversation else { return false }

            ZMUserSession.shared()?.enqueueChanges({
                conversation.isArchived = false
            }, completionHandler: {
                self.internalSelect(itemToSelect: itemToSelect)
            })
        } else {
            internalSelect(itemToSelect: itemToSelect)
        }

        return true
    }

    private func internalSelect(itemToSelect: AnyHashable?) {
        selectedItem = itemToSelect
        delegate?.listViewModel(self, didSelectItem: itemToSelect)
    }

    // MARK: - collapse section

    func collapsed(at sectionIndex: Int) -> Bool {
        return collapsed(at: sectionIndex, state: state)
    }

    private func collapsed(at sectionIndex: Int, state: State) -> Bool {
        guard let kind = kind(of: sectionIndex) else { return false }

        return state.collapsed.contains(kind.identifier)
    }
    
    func setCollapsed(sectionIndex: Int,
                      collapsed: Bool,
                      batchUpdate: Bool = true) {
        guard let kind = self.kind(of: sectionIndex) else { return }
        guard self.collapsed(at: sectionIndex) != collapsed else { return }
        
        if collapsed {
            state.collapsed.insert(kind.identifier)
        } else {
            state.collapsed.remove(kind.identifier)
        }
        
        updateForConversationType(kind: kind)
    }

    // MARK: - state presistent

    private struct State: Codable, Equatable {
        var collapsed: Set<SectionIdentifier>
        var folderEnabled: Bool

        init() {
            collapsed = []
            folderEnabled = false
        }

        var jsonString: String? {
            guard let jsonData = try? JSONEncoder().encode(self) else {
                return nil }

            return String(data: jsonData, encoding: .utf8)
        }
    }

    var jsonString: String? {
        return state.jsonString
    }

    private func saveState(state: State) {

        guard let jsonString = state.jsonString,
              let persistentDirectory = ConversationListViewModel.persistentDirectory,
              let directoryURL = URL.directoryURL(persistentDirectory) else { return }

        FileManager.default.createAndProtectDirectory(at: directoryURL)

        do {
            try jsonString.write(to: directoryURL.appendingPathComponent(ConversationListViewModel.persistentFilename), atomically: true, encoding: .utf8)
        } catch {
            log.error("error writing ConversationListViewModel to \(directoryURL): \(error)")
        }
    }

    private static var persistentDirectory: String? {
        guard let userID = ZMUser.selfUser()?.remoteIdentifier else { return nil }

        return "UI_state/\(userID)"
    }

    private static var persistentFilename: String {
        let className = String(describing: self)
        return "\(className).json"
    }

    static var persistentURL: URL? {
        guard let persistentDirectory = persistentDirectory else { return nil }

        return URL.directoryURL(persistentDirectory)?.appendingPathComponent(ConversationListViewModel.persistentFilename)
    }
}

// MARK: - ZMUserObserver

fileprivate let log = ZMSLog(tag: "ConversationListViewModel")

// MARK: - ConversationDirectoryObserver

extension ConversationListViewModel: ConversationDirectoryObserver {
    func conversationDirectoryDidChange(_ changeInfo: ConversationDirectoryChangeInfo) {

        if changeInfo.reloaded {
            // If the section was empty in certain cases collection view breaks down on the big amount of conversations,
            // so we prefer to do the simple reload instead.
            reload()
        } else {
            ///TODO: When 2 sections are visible and a conversation belongs to both, the lower section's update animation is missing since it started after the top section update animation started. To fix this we should calculate the change set in one batch.
            /// TODO: wait for SE update for returning multiple items in changeInfo.updatedLists
            for updatedList in changeInfo.updatedLists {
                if let kind = self.kind(of: updatedList) {
                    updateForConversationType(kind: kind)
                }
            }
        }
    }

    private func kind(of conversationListType: ConversationListType) -> Section.Kind? {

        let kind: Section.Kind?

        switch conversationListType {
        case .unarchived:
            kind = .conversations
        case .contacts:
            kind = .contacts
        case .pending:
            kind = .contactRequests
        case .groups:
            kind = .groups
        case .favorites:
            kind = .favorites
        case .folder(let label):
            kind = .folder(label: label)
        case .archived:
            kind = nil
        }
        
        return kind

    }
}
