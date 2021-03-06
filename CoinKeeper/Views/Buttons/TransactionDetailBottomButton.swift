//
//  TransactionDetailBottomButton.swift
//  DropBit
//
//  Created by Ben Winters on 4/12/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class TransactionDetailBottomButton: UIButton {
  override func awakeFromNib() {
    super.awakeFromNib()
    applyCornerRadius(4)
    backgroundColor = .darkBlueBackground
    setTitleColor(.extraLightGrayBackground, for: .normal)
    titleLabel?.font = .primaryButtonTitle
  }
}
