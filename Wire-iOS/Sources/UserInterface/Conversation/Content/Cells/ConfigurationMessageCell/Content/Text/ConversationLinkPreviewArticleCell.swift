//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

import UIKit

class ConversationLinkPreviewArticleCell: UIView, ConversationMessageCell {

    struct Configuration {
        let textMessageData: ZMTextMessageData
        let isObfuscated: Bool
        let showImage: Bool
    }

    private let articleView = ArticleView(withImagePlaceholder: true)

    var isSelected: Bool = false

    var selectionView: UIView? {
        return articleView
    }

    var configuration: Configuration?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
        configureConstraints()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureSubviews()
        configureConstraints()
    }

    private func configureSubviews() {
        addSubview(articleView)
    }

    private func configureConstraints() {
        articleView.translatesAutoresizingMaskIntoConstraints = false
        articleView.fitInSuperview()
    }

    func configure(with object: Configuration, animated: Bool) {
        configuration = object
        articleView.configure(withTextMessageData: object.textMessageData, obfuscated: object.isObfuscated)
        updateImageLayout(isRegular: self.traitCollection.horizontalSizeClass == .regular)
    }

    func updateImageLayout(isRegular: Bool) {
        if configuration?.showImage == true {
            articleView.imageHeight = isRegular ? 125 : 75
        } else {
            articleView.imageHeight = 0
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateImageLayout(isRegular: self.traitCollection.horizontalSizeClass == .regular)
    }

}

class ConversationLinkPreviewArticleCellDescription: ConversationMessageCellDescription {
    typealias View = ConversationLinkPreviewArticleCell
    let configuration: View.Configuration

    weak var message: ZMConversationMessage?
    weak var delegate: ConversationCellDelegate? 
    weak var actionController: ConversationCellActionController?
    
    var topMargin: Float = 8

    var isFullWidth: Bool {
        return false
    }

    var supportsActions: Bool {
        return true
    }

    init(message: ZMConversationMessage, data: ZMTextMessageData) {
        let showImage = data.linkPreviewHasImage
        configuration = View.Configuration(textMessageData: data, isObfuscated: message.isObfuscated, showImage: showImage)
    }
}