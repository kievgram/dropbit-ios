//
//  MockTransactionDetailCellViewModel.swift
//  DropBit
//
//  Created by Ben Winters on 9/23/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit

typealias MockDetailCellVM = MockTransactionDetailCellViewModel
class MockTransactionDetailCellViewModel: MockTransactionSummaryCellViewModel, TransactionDetailCellViewModelType {

  var date: Date
  var memoIsShared: Bool
  var invitationStatus: InvitationStatus?
  var onChainConfirmations: Int?
  var addressProvidedToSender: String?

  init(walletTxType: WalletTransactionType,
       direction: TransactionDirection,
       status: TransactionStatus,
       onChainConfirmations: Int?,
       isLightningTransfer: Bool,
       receiverAddress: String?,
       addressProvidedToSender: String?,
       lightningInvoice: String?,
       selectedCurrency: SelectedCurrency,
       amountDetails: TransactionAmountDetails,
       counterpartyConfig: TransactionCellCounterpartyConfig?,
       invitationStatus: InvitationStatus?,
       memo: String?,
       memoIsShared: Bool,
       date: Date) {
    self.date = date
    self.memoIsShared = memoIsShared
    self.invitationStatus = invitationStatus
    self.onChainConfirmations = onChainConfirmations
    self.addressProvidedToSender = addressProvidedToSender

    super.init(walletTxType: walletTxType, direction: direction, status: status,
               isLightningTransfer: isLightningTransfer, receiverAddress: receiverAddress,
               lightningInvoice: lightningInvoice, selectedCurrency: selectedCurrency,
               amountDetails: amountDetails, counterpartyConfig: counterpartyConfig, memo: memo)
  }

  static func testDetailInstance(walletTxType: WalletTransactionType = .onChain,
                                 direction: TransactionDirection = .out,
                                 status: TransactionStatus = .completed,
                                 onChainConfirmations: Int? = nil,
                                 isLightningTransfer: Bool = false,
                                 receiverAddress: String? = nil,
                                 addressProvidedToSender: String? = nil,
                                 lightningInvoice: String? = nil,
                                 selectedCurrency: SelectedCurrency = .fiat,
                                 amountDetails: TransactionAmountDetails? = nil,
                                 counterpartyConfig: TransactionCellCounterpartyConfig? = nil,
                                 invitationStatus: InvitationStatus? = nil,
                                 memo: String? = nil,
                                 memoIsShared: Bool = false,
                                 date: Date = Date()) -> MockTransactionDetailCellViewModel {

    let amtDetails = amountDetails ?? MockTransactionSummaryCellViewModel.testAmountDetails(sats: 49500)
    return MockTransactionDetailCellViewModel(
      walletTxType: walletTxType, direction: direction,
      status: status, onChainConfirmations: onChainConfirmations, isLightningTransfer: isLightningTransfer,
      receiverAddress: receiverAddress, addressProvidedToSender: addressProvidedToSender, lightningInvoice: lightningInvoice,
      selectedCurrency: selectedCurrency, amountDetails: amtDetails,
      counterpartyConfig: counterpartyConfig, invitationStatus: invitationStatus,
      memo: memo, memoIsShared: memoIsShared, date: date)
  }

}
