//
//  NSAttributedString+Helpers.swift
//  DropBit
//
//  Created by Mitch on 1/24/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

extension NSAttributedString {
  static func + (left: NSAttributedString, right: NSAttributedString) -> NSAttributedString {
    let result = NSMutableAttributedString()
    result.append(left)
    result.append(right)
    return result
  }

  static func + (left: NSAttributedString, right: String) -> NSAttributedString {
    let rightAttributedString = NSAttributedString(string: right)

    let result = NSMutableAttributedString()
    result.append(left)
    result.append(rightAttributedString)
    return result
  }

  convenience init(image: UIImage,
                   fontDescender: CGFloat,
                   imageSize: CGSize = CGSize(width: 20, height: 20),
                   offset: CGPoint = .zero) {
    let textAttribute = NSTextAttachment()
    textAttribute.image = image
    textAttribute.bounds = CGRect(
      x: 0,
      y: fontDescender, //(-size.height / (size.height / 3)),
      width: imageSize.width,
      height: imageSize.height
      ).offsetBy(dx: offset.x, dy: offset.y)

    self.init(attachment: textAttribute)
  }

  /// `sharedColor` is used for both the titleColor and a mask of the image
  convenience init(imageName: String,
                   imageSize: CGSize = CGSize(width: 20, height: 20),
                   title: String,
                   sharedColor: UIColor,
                   font: UIFont,
                   imageOffset: CGPoint = .zero,
                   trailingImage: Bool = false) {

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: sharedColor
    ]

    let image = UIImage(imageLiteralResourceName: imageName).maskWithColor(color: sharedColor)
    let attributedImage = NSAttributedString(image: image,
                                             fontDescender: font.descender,
                                             imageSize: imageSize,
                                             offset: imageOffset)
    let space = "  "
    let attributedText = NSAttributedString(string: title, attributes: attributes)

    if trailingImage {
      self.init(attributedString: attributedText + space + attributedImage)
    } else {
      self.init(attributedString: attributedImage + space + attributedText)
    }
  }

  convenience init(string: String, color: UIColor, font: UIFont) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color
    ]
    self.init(string: string, attributes: attributes)
  }

}
