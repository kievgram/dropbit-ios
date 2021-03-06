//
//  DrawerTableViewHeader.swift
//  DropBit
//
//  Created by Mitchell Malleo on 4/6/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit

class DrawerTableViewHeader: UITableViewHeaderFooterView {

  @IBOutlet var _backgroundView: UIView!
  @IBOutlet var priceTitleLabel: UILabel!
  @IBOutlet var priceLabel: UILabel!

  public weak var currencyValueManager: CurrencyValueDataSourceType?

  private lazy var formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    formatter.locale = .US
    formatter.usesGroupingSeparator = true
    formatter.numberStyle = .currency
    return formatter
  }()

  deinit {
    CKNotificationCenter.unsubscribe(self)
  }

  override func awakeFromNib() {
    super.awakeFromNib()

    priceLabel.textColor = UIColor.white
    priceTitleLabel.textColor = UIColor.white
    priceTitleLabel.text = "Current Price"
    priceTitleLabel.font = .light(11.6)
    priceLabel.font = .regular(16)
    _backgroundView.backgroundColor = .darkBlueBackground

    refreshDisplayedPrice()

    //Need to listen for correct notification
    CKNotificationCenter.subscribe(self, [.didUpdateExchangeRates: #selector(refreshDisplayedPrice)])
  }

  @objc private func refreshDisplayedPrice() {
    currencyValueManager?.latestExchangeRates(responseHandler: updateRatesRequest)
  }

  /// A closure to be called by the delegate during viewDidLoad and when a .didUpdateExchangeRates notification has been received
  lazy var updateRatesRequest: ExchangeRatesRequest = { [weak self] rates in
    let value = rates[.USD] as NSNumber?
    self?.priceLabel.text = self?.formatter.string(from: value ?? 0.0)
  }
}
