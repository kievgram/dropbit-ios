//
//  LightningTransactionHistoryEmptyView.swift
//  DropBit
//
//  Created by Mitchell Malleo on 8/6/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol LightningTransactionHistoryEmptyViewDelegate: AnyObject {
  func emptyViewDidRequestCustomAmount()
  func emptyViewDidRequestRefill(withAmount amount: LightningTransactionHistoryEmptyView.Amount)
}

class LightningTransactionHistoryEmptyView: UIView {
  enum Amount {
    case low
    case medium
    case high
    case max
  }

  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var detailLabel: UILabel!
  @IBOutlet var lowAmountButton: LightningActionButton!
  @IBOutlet var mediumAmountButton: LightningActionButton!
  @IBOutlet var highAmountButton: LightningActionButton!
  @IBOutlet var maxAmountButton: LightningActionButton!
  @IBOutlet var customAmountButton: UIButton!

  weak var delegate: LightningTransactionHistoryEmptyViewDelegate?

  override func awakeFromNib() {
    super.awakeFromNib()

    titleLabel.font = .medium(17)
    titleLabel.textColor = .darkGrayText

    detailLabel.font = .regular(12)
    detailLabel.textColor = .lightningBlue

    customAmountButton.titleLabel?.textColor = .darkGrayText
    customAmountButton.tintColor = .darkGray
    customAmountButton.titleLabel?.font = .medium(16)
  }

  @IBAction func fiveButtonWasTouched() {
    delegate?.emptyViewDidRequestRefill(withAmount: .low)
  }

  @IBAction func twentyButtonWasTouched() {
    delegate?.emptyViewDidRequestRefill(withAmount: .medium)
  }

  @IBAction func fiftyButtonWasTouched() {
    delegate?.emptyViewDidRequestRefill(withAmount: .high)
  }

  @IBAction func hundredButtonWasTouched() {
    delegate?.emptyViewDidRequestRefill(withAmount: .max)
  }

  @IBAction func customAmountButtonWasTouched() {
    delegate?.emptyViewDidRequestCustomAmount()
  }

}
