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

typealias AlertActionHandler = ((UIAlertAction) -> Void)
extension UIAlertAction {

    static func cancel(cancelButtonTitle: String? = "general.cancel".localized,
                       completion: (() -> Void)? = nil) -> UIAlertAction {
        return UIAlertAction(
            title: cancelButtonTitle,
            style: .cancel,
            handler: { _ in completion?() }
        )
    }

    static func ok(style: Style = .default, _ handler:AlertActionHandler? = nil) -> UIAlertAction {
        return UIAlertAction(
            title: "general.ok".localized,
            style: style,
            handler: handler
        )
    }

    convenience init(icon: StyleKitIcon?, title: String, tintColor: UIColor, handler: ((UIAlertAction) -> Void)? = nil) {
        self.init(title: title, style: .default, handler: handler);

        setValue(CATextLayerAlignmentMode.left, forKey: "titleTextAlignment")

        if let icon = icon {
            let image = UIImage.imageForIcon(icon, size: 24, color: tintColor)
            setValue(image.withRenderingMode(.alwaysOriginal), forKey: "image")
        }
    }
}
