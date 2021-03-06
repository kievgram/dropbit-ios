//
//  WalletManager.swift
//  DropBit
//
//  Created by BJ Miller on 3/5/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import CNBitcoinKit
import CoreData
import PromiseKit

protocol WalletManagerType: AnyObject {
  static func createMnemonicWords() -> [String]
  static func validateBase58Check(for address: String) -> Bool
  static func validateBech32Encoding(for address: String) -> Bool
  var coin: CNBBaseCoin { get }
  var wallet: CNBHDWallet { get }
  var hexEncodedPublicKey: String { get }
  func signatureSigning(data: Data) -> String
  func usableFeeRate(from feeRate: Double) -> UInt
  func mnemonicWords() -> [String]
  func resetWallet(with words: [String])

  func createAddressDataSource() -> AddressDataSourceType

  /// Use this when displaying the balance
  func balanceNetPending(in context: NSManagedObjectContext) -> (onChain: Int, lightning: Int)

  /// Spendable UTXOs
  /// number of confirmations affects isSpendable, returns a min of 0
  func spendableBalance(in context: NSManagedObjectContext) -> (onChain: Int, lightning: Int)

  func activeTemporarySentTxTotal(forType walletTxType: WalletTransactionType,
                                  in context: NSManagedObjectContext) -> Int

  func transactionData(forPayment payment: NSDecimalNumber,
                       to address: String,
                       withFeeRate feeRate: Double,
                       rbfOption: CNBTransactionReplaceabilityOption) -> Promise<CNBTransactionData>

  /// Returns nil instead of an error in the case of insufficient funds, uses default `rbfOption: .Allowed`
  func failableTransactionData(forPayment payment: NSDecimalNumber,
                               to address: String,
                               withFeeRate feeRate: Double) -> CNBTransactionData?

  func failableTransactionData(forPayment payment: NSDecimalNumber,
                               to address: String,
                               withFeeRate feeRate: Double,
                               rbfOption: CNBTransactionReplaceabilityOption) -> CNBTransactionData?

  /// Transaction data for payment to a recipient with a flat, predetermined fee.
  ///
  /// - Parameters:
  ///   - payment: Amount (in satoshis) to pay.
  ///   - address: Destination payment address.
  ///   - flatFee: Predetermined fee (NOT a rate) for the transaction
  /// - Returns: A Promise that either contains a CNBTransactionData object, or rejects if insufficient funds.
  func transactionData(
    forPayment payment: Int,
    to address: String,
    withFlatFee flatFee: Int
    ) -> Promise<CNBTransactionData>

  /// Transaction data for sending max wallet amount, minus fee, to a given address.
  ///
  /// - Parameters:
  ///   - address: Destination payment address.
  ///   - feeRate: Fee rate per bytes, in Satoshis
  /// - Returns: A Promise that either contains a CNBTransactionData object, ro rejects if insufficient funds.
  func transactionDataSendingMax(to address: String, withFeeRate feeRate: Double) -> Promise<CNBTransactionData>

  /// Returns nil instead of an error in the case of insufficient funds
  func failableTransactionDataSendingMax(to address: String, withFeeRate feeRate: Double) -> CNBTransactionData?

  /// Returns nil instead of an error in the case of insufficient funds. Takes all unspent outputs, ignoring dust protection and confirmation count.
  func failableTransactionDataSendingAll(to address: String, withFeeRate feeRate: Double) -> CNBTransactionData?
  func transactionDataSendingAll(to address: String, withFeeRate feeRate: Double) -> Promise<CNBTransactionData>

  func encryptionCipherKeys(forUncompressedPublicKey pubkey: Data, withEntropy: Bool) -> CNBEncryptionCipherKeys
  func decryptionCipherKeys(forReceiveAddressPath path: CKMDerivativePath,
                            withPublicKey pubkey: Data) -> CNBCipherKeys
  func decryptionCipherKeysWithDefaultPrivateKey(forPublicKey pubKey: Data) -> CNBCipherKeys

  func encryptPayload<T>(_ payload: T, addressPubKey: String, keyIsEphemeral: Bool) -> Promise<String> where T: SharedPayloadCodable
}

/**
 Warning: Do not store a reference to the wallet manager outside of the single instance assigned to the AppCoordinator.
 All other classes should keep a delegate (WalletDelegateType) reference to the AppCoordinator to access the single wallet manager.

 This is particularly important if the user deleted their wallet and created a new wallet,
 in which case the old wallet manager would still be in memory for any class keeping a reference to it.
 */
class WalletManager: WalletManagerType {

  private(set) var wallet: CNBHDWallet
  private let persistenceManager: PersistenceManagerType

  let coin: CNBBaseCoin

  init(words: [String], persistenceManager: PersistenceManagerType = PersistenceManager()) {
    let relevantCoin = persistenceManager.usableCoin
    self.wallet = CNBHDWallet(mnemonic: words, coin: relevantCoin)
    self.coin = relevantCoin
    self.persistenceManager = persistenceManager
  }

  func encryptionCipherKeys(forUncompressedPublicKey pubkey: Data, withEntropy: Bool) -> CNBEncryptionCipherKeys {
    if withEntropy {
      return wallet.encryptionCipherKeys(forPublicKey: pubkey, withEntropy: WalletManager.secureEntropy())
    } else {
      return wallet.encryptionCipherKeys(forPublicKey: pubkey)
    }
  }

  func decryptionCipherKeys(forReceiveAddressPath path: CKMDerivativePath,
                            withPublicKey pubkey: Data) -> CNBCipherKeys {
    let cnbPath = path.asCNBDerivationPath()
    return wallet.decryptionCipherKeysForDerivationPath(ofPrivateKey: cnbPath, publicKey: pubkey)
  }

  func decryptionCipherKeysWithDefaultPrivateKey(forPublicKey pubKey: Data) -> CNBCipherKeys {
    return wallet.decryptionCipherKeysWithDefaultPrivateKey(forPublicKey: pubKey)
  }

  func encryptPayload<T>(_ payload: T, addressPubKey: String, keyIsEphemeral: Bool) -> Promise<String> where T: SharedPayloadCodable {
    guard let addressPubKeyData = Data(fromHexEncodedString: addressPubKey) else {
      return Promise(error: CKPersistenceError.missingValue(key: "addressPubKeyData"))
    }

    return Promise { seal in
      do {
        let encodedPayload = try payload.encoded()
        let cryptor = CKCryptor(walletManager: self)
        let encryptedPayloadString = try cryptor.encryptAsBase64String(message: encodedPayload,
                                                                       withRecipientUncompressedPubkey: addressPubKeyData,
                                                                       isEphemeral: keyIsEphemeral)
        seal.fulfill(encryptedPayloadString)
      } catch {
        seal.reject(error)
      }
    }
  }

  private static func secureEntropy() -> Data {
    let len = 16; // 16 bytes
    var data = Data(count: len)

    let result = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, len, $0.baseAddress!) }

    guard result == errSecSuccess else { return Data() }

    return data
  }

  public static func createMnemonicWords() -> [String] {
    var words: [String] = []
    while words.count != 12 {
      let entropy = secureEntropy()
      words = CNBHDWallet.createMnemonicWords(withEntropy: entropy)
    }
    return words
  }

  static func validateBase58Check(for address: String) -> Bool {
    return CNBHDWallet.addressIsBase58CheckEncoded(address)
  }

  static func validateBech32Encoding(for address: String) -> Bool {
    return CNBSegwitAddress.isValidP2WPKHAddress(address) || CNBSegwitAddress.isValidP2WSHAddress(address)
  }

  var minimumFeeRate: UInt {
    return 1
  }

  func createAddressDataSource() -> AddressDataSourceType {
    return AddressDataSource(wallet: self.wallet, persistenceManager: self.persistenceManager)
  }

  func activeTemporarySentTxTotal(forType walletTxType: WalletTransactionType,
                                  in context: NSManagedObjectContext) -> Int {
    let tempTransactions: [CKMTemporarySentTransaction]
    switch walletTxType {
    case .onChain:    tempTransactions = CKMTemporarySentTransaction.findAllActiveOnChain(in: context)
    case .lightning:  tempTransactions = CKMTemporarySentTransaction.findAllActiveLightning(in: context)
    }

    //use totalAmount for both walletTxTypes since we cover fees for lightning load transactions
    let total = tempTransactions.reduce(0) { $0 + $1.totalAmount }
    return total
  }

  func balanceNetPending(in context: NSManagedObjectContext) -> (onChain: Int, lightning: Int) {
    let wallet = CKMWallet.findOrCreate(in: context)
    let atss = CKMAddressTransactionSummary.findAll(matching: self.coin, in: context)
    let atsAmount = atss.reduce(0) { $0 + $1.netAmount }
    let tempSentTxTotal = activeTemporarySentTxTotal(forType: .onChain, in: context)
    let netOnChainBalance = atsAmount - tempSentTxTotal

    let lightningAccount = persistenceManager.brokers.lightning.getAccount(forWallet: wallet, in: context)
    let tempSentLightningTotal = activeTemporarySentTxTotal(forType: .lightning, in: context)
    let netLightningBalance = lightningAccount.balance + lightningAccount.pendingIn + tempSentLightningTotal
    return (onChain: netOnChainBalance, lightning: netLightningBalance)
  }

  func spendableBalance(in context: NSManagedObjectContext) -> (onChain: Int, lightning: Int) {
    guard let wallet = CKMWallet.find(in: context) else { return (0, 0) }
    let minAmount = self.persistenceManager.brokers.preferences.dustProtectionMinimumAmount
    let lightningAccount = self.persistenceManager.brokers.lightning.getAccount(forWallet: wallet, in: context)
    let spendableVouts = CKMVout.findAllSpendable(minAmount: minAmount, in: context)
    let spendableTotal = spendableVouts.reduce(0) { $0 + $1.amount }

    return (onChain: spendableTotal, lightning: lightningAccount.balance)
  }

  var hexEncodedPublicKey: String {
    return wallet.coinNinjaVerificationKeyHexString
  }

  func resetWallet(with words: [String]) {
    self.wallet = CNBHDWallet(mnemonic: words, coin: coin)
  }

  func mnemonicWords() -> [String] {
    return wallet.mnemonicWords().compactMap { $0 as? String }
  }

  func signatureSigning(data: Data) -> String {
    return wallet.signatureSigning(data)
  }

  func usableFeeRate(from feeRate: Double) -> UInt {
    let floored = floor(feeRate)
    return max(UInt(exactly: floored) ?? 0, minimumFeeRate)
  }

  func transactionData(
    forPayment payment: NSDecimalNumber,
    to address: String,
    withFeeRate feeRate: Double,  // in Satoshis
    rbfOption: CNBTransactionReplaceabilityOption
    ) -> Promise<CNBTransactionData> {

    return Promise { seal in
      let txData = failableTransactionData(forPayment: payment,
                                           to: address,
                                           withFeeRate: feeRate,
                                           rbfOption: rbfOption)
      if let data = txData {
        seal.fulfill(data)
      } else {
        seal.reject(TransactionDataError.insufficientFunds)
      }
    }
  }

  func failableTransactionData(forPayment payment: NSDecimalNumber, to address: String, withFeeRate feeRate: Double) -> CNBTransactionData? {
    return failableTransactionData(forPayment: payment, to: address, withFeeRate: feeRate, rbfOption: .Allowed)
  }

  func failableTransactionData(
    forPayment payment: NSDecimalNumber,
    to address: String,
    withFeeRate feeRate: Double,
    rbfOption: CNBTransactionReplaceabilityOption) -> CNBTransactionData? {
    let paymentAmount = UInt(payment.asFractionalUnits(of: .BTC))
    let usableFeeRate = self.usableFeeRate(from: feeRate)
    let blockHeight = UInt(persistenceManager.brokers.checkIn.cachedBlockHeight)
    let bgContext = persistenceManager.createBackgroundContext()
    var result: CNBTransactionData?
    bgContext.performAndWait {
      let usableVouts = self.usableVouts(in: bgContext)
      let allAvailableOutputs = self.availableTransactionOutputs(fromUsableUTXOs: usableVouts)

      result = CNBTransactionData(
        address: address,
        coin: coin,
        fromAllAvailableOutputs: allAvailableOutputs,
        paymentAmount: paymentAmount,
        feeRate: usableFeeRate,
        change: self.newChangePath(in: bgContext),
        blockHeight: blockHeight,
        rbfReplaceabilityOption: rbfOption
      )
    }
    return result
  }

  func transactionData(
    forPayment payment: Int,
    to address: String,
    withFlatFee flatFee: Int
    ) -> Promise<CNBTransactionData> {

    return Promise { seal in
      guard flatFee > 0 else {
        log.error("flatFee was zero. payment: %d, to address: %@", privateArgs: [payment, address])
        seal.reject(TransactionDataError.insufficientFee)
        return
      }
      let bgContext = persistenceManager.createBackgroundContext()
      bgContext.perform { [weak self] in
        guard let strongSelf = self else {
          seal.reject(CKSystemError.missingValue(key: "wallet manager self"))
          return
        }
        let usableVouts = strongSelf.usableVouts(in: bgContext)
        let allAvailableOutputs = strongSelf.availableTransactionOutputs(fromUsableUTXOs: usableVouts)
        let paymentAmount = UInt(payment)
        let feeAmount = UInt(flatFee)
        let blockHeight = UInt(strongSelf.persistenceManager.brokers.checkIn.cachedBlockHeight)

        let txData = CNBTransactionData(
          address: address,
          coin: strongSelf.coin,
          fromAllAvailableOutputs: allAvailableOutputs,
          paymentAmount: paymentAmount,
          flatFee: feeAmount,
          change: strongSelf.newChangePath(in: bgContext),
          blockHeight: blockHeight
        )
        if let data = txData {
          seal.fulfill(data)
        } else {
          seal.reject(TransactionDataError.insufficientFunds)
        }
      }
    }
  }

  func transactionDataSendingMax(to address: String, withFeeRate feeRate: Double) -> Promise<CNBTransactionData> {
    return Promise { seal in
      let maybeTxData = self.failableTransactionDataSendingMax(to: address, withFeeRate: feeRate)
      if let data = maybeTxData {
        seal.fulfill(data)
      } else {
        seal.reject(TransactionDataError.insufficientFunds)
      }
    }
  }

  func failableTransactionDataSendingMax(to address: String, withFeeRate feeRate: Double) -> CNBTransactionData? {
    let usableFeeRate = self.usableFeeRate(from: feeRate)
    let blockHeight = UInt(persistenceManager.brokers.checkIn.cachedBlockHeight)
    let bgContext = persistenceManager.createBackgroundContext()

    var result: CNBTransactionData?
    bgContext.performAndWait {
      let usableVouts = self.usableVouts(in: bgContext)
      let allAvailableOutputs = self.availableTransactionOutputs(fromUsableUTXOs: usableVouts)

      ///This initializer uses CNBTransactionReplaceabilityOption.MustNotBeRBF
      result = CNBTransactionData(
        allUsableOutputs: allAvailableOutputs,
        coin: coin,
        sendingMaxToAddress: address,
        feeRate: usableFeeRate,
        blockHeight: blockHeight
      )
    }
    return result
  }

  func transactionDataSendingAll(to address: String, withFeeRate feeRate: Double) -> Promise<CNBTransactionData> {
    return Promise { seal in
      let context = persistenceManager.viewContext
      let unspent = CKMVout.unspentBalance(in: context)
      guard unspent > 0 else {
        seal.reject(TransactionDataError.noSpendableFunds)
        return
      }

      let maybeTxData = self.failableTransactionDataSendingAll(to: address, withFeeRate: feeRate)
      if let data = maybeTxData {
        seal.fulfill(data)
      } else {
        seal.reject(TransactionDataError.insufficientFunds)
      }
    }
  }

  func failableTransactionDataSendingAll(to address: String, withFeeRate feeRate: Double) -> CNBTransactionData? {
    let usableFeeRate = self.usableFeeRate(from: feeRate)
    let blockHeight = UInt(persistenceManager.brokers.checkIn.cachedBlockHeight)
    let context = persistenceManager.viewContext

    var result: CNBTransactionData?
    context.performThrowingAndWait {
      let vouts = try? CKMVout.findAllUnspent(in: context)
      let utxos = vouts.map { self.availableTransactionOutputs(fromUsableUTXOs: $0) }
      result = utxos.flatMap {
        CNBTransactionData(allUsableOutputs: $0, coin: self.coin, sendingMaxToAddress: address, feeRate: usableFeeRate, blockHeight: blockHeight)
      }
    }
    return result
  }

  /// - parameter limitByPending: true to remove the smallest vouts, to not exceed spendableBalanceNetPending()
  private func usableVouts(in context: NSManagedObjectContext) -> [CKMVout] {
    let dustProtectionAmount = self.persistenceManager.brokers.preferences.dustProtectionMinimumAmount
    return CKMVout.findAllSpendable(minAmount: dustProtectionAmount, in: context)
  }

  private func availableTransactionOutputs(fromUsableUTXOs usableUTXOs: [CKMVout]) -> [CNBUnspentTransactionOutput] {
    return usableUTXOs.compactMap { (vout: CKMVout) -> CNBUnspentTransactionOutput? in
      guard let transaction = vout.transaction,
        let derivationPath = vout.address?.derivativePath
        else { return nil }

      let index = UInt(vout.index)
      let amount = UInt(vout.amount)
      let cnbDerivativePath = CNBDerivationPath(
        purpose: CoinDerivation(rawValue: UInt(derivationPath.purpose)) ?? .BIP84,
        coinType: CoinType(rawValue: UInt(derivationPath.coin)) ?? .MainNet,
        account: UInt(derivationPath.account),
        change: UInt(derivationPath.change),
        index: UInt(derivationPath.index)
      )
      let output = CNBUnspentTransactionOutput(id: transaction.txid,
                                               index: index,
                                               amount: amount,
                                               derivationPath: cnbDerivativePath,
                                               isConfirmed: transaction.isConfirmed)
      return output
    }
  }

  private func newChangePath(in context: NSManagedObjectContext) -> CNBDerivationPath {
    let changeAddress = self.createAddressDataSource().nextChangeAddress(in: context)
    return CNBDerivationPath(
      purpose: CoinDerivation(rawValue: changeAddress.derivationPath.purpose.rawValue) ?? .BIP84,
      coinType: CoinType(rawValue: changeAddress.derivationPath.coinType.rawValue) ?? .MainNet,
      account: changeAddress.derivationPath.account,
      change: changeAddress.derivationPath.change,
      index: changeAddress.derivationPath.index
    )
  }

}
