//
//  Database.swift
//  DropBit
//
//  Created by BJ Miller on 3/8/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import CoreData
import PromiseKit
import CNBitcoinKit

class CKDatabase: PersistenceDatabaseType {

  private let stackConfig: CoreDataStackConfig
  private let container: NSPersistentContainer

  var sharedPayloadManager: SharedPayloadManagerType = SharedPayloadManager()

  convenience init() {
    let stackConfig = CoreDataStackConfig(stackType: .main, storeType: .disk)
    self.init(stackConfig: stackConfig)
  }

  init(stackConfig: CoreDataStackConfig) {
    self.stackConfig = stackConfig
    self.container = stackConfig.stack.persistentContainer
  }

  private lazy var rootContext: NSManagedObjectContext = {
    let context = self.container.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    context.name = "RootContext"
    return context
  }()

  lazy var viewContext: NSManagedObjectContext = {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.parent = rootContext
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    context.name = "ViewContext"
    return context
  }()

  /// Be sure to call saveRecursively(), parent is viewContext.
  func createBackgroundContext() -> NSManagedObjectContext {
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.parent = viewContext
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    context.name = "BackgroundContext_\(Date().timeIntervalSince1970)"
    return context
  }

  func persistentStore(for context: NSManagedObjectContext) -> NSPersistentStore? {
    return context.persistentStoreCoordinator?.persistentStores.first
  }

  private func executeBatchDeleteFor(entity name: String, in context: NSManagedObjectContext) {
    let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: name)
    let request = NSBatchDeleteRequest(fetchRequest: fetch)
    request.resultType = .resultTypeObjectIDs

    context.performAndWait {
      do {
        if let result = try context.execute(request) as? NSBatchDeleteResult, let objectIDs = result.result as? [NSManagedObjectID] {
          NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [context])
        }
      } catch {
        fatalError("Failed to execute request: \(error)")
      }
    }
  }

  func deleteAll(in context: NSManagedObjectContext) {
    context.performAndWait {
      self.stackConfig.model?.entities
        .compactMap { $0.name }
        .forEach { executeBatchDeleteFor(entity: $0, in: context) }
    }
  }

  func unverifyUser(in context: NSManagedObjectContext) {
    var user: CKMUser?

    context.performAndWait {
      let allServerAddresses = serverPoolAddresses(in: context)
      let serverDerivativePaths = allServerAddresses.compactMap { $0.derivativePath }.filter { $0.address == nil }
      allServerAddresses.forEach { context.delete($0) }
      serverDerivativePaths.forEach { context.delete($0) }

      CKMInvitation.find(withStatuses: [.requestSent, .addressSent], in: context).forEach { $0.status = .canceled }
      CKMInvitation.find(withStatuses: [.notSent], in: context).forEach { context.delete($0) }

      user = CKMUser.find(in: context)
      user.flatMap { context.delete($0) }

      do {
        try context.save()
      } catch {
        log.contextSaveError(error)
      }
    }
  }

  func removeWalletId(in context: NSManagedObjectContext) {
    guard let wallet = CKMWallet.find(in: context) else {
      return
    }

    wallet.id = nil
  }

  func walletId(in context: NSManagedObjectContext) -> String? {
    var id: String?

    context.performAndWait {
      id = CKMWallet.find(in: context)?.id
    }

    return id
  }

  func walletFlags(in context: NSManagedObjectContext) -> Int {
    guard let wallet = CKMWallet.find(in: context) else { return 0 }
    return wallet.flags
  }

  func persistWalletResponse(_ response: WalletResponse, in context: NSManagedObjectContext) throws {
    guard let wallet = CKMWallet.find(in: context) else {
      throw CKPersistenceError.noManagedWallet
    }

    wallet.id = response.id
    wallet.flags = response.flags
  }

  func containsRegularTransaction(in context: NSManagedObjectContext) -> IncomingOutgoingTuple {
    return CKMTransaction.containsRegularTransaction(in: context)
  }

  func containsDropbitTransaction(in context: NSManagedObjectContext) -> IncomingOutgoingTuple {
    return CKMTransaction.containsDropbitTransaction(in: context)
  }

  func userId(in context: NSManagedObjectContext) -> String? {
    return CKMUser.find(in: context)?.id
  }

  func userVerificationStatus(in context: NSManagedObjectContext) -> UserVerificationStatus {
    return CKMUser.find(in: context)?.verificationStatusCase ?? .unverified
  }

  func persistUserId(_ id: String, in context: NSManagedObjectContext) {
    _ = CKMUser.updateOrCreate(with: id, in: context)
  }

  func persistVerificationStatus(_ status: String, in context: NSManagedObjectContext) -> Promise<UserVerificationStatus> {
    return Promise { seal in
      context.performAndWait {
        guard let user = CKMUser.find(in: context) else {
          seal.reject(CKPersistenceError.noUser)
          return
        }

        user.verificationStatus = status

        seal.fulfill(user.verificationStatusCase)

      }
    }
  }

  func persistServerAddress(
    for metaAddress: CNBMetaAddress,
    createdAt: Date,
    wallet: CKMWallet,
    in context: NSManagedObjectContext) -> Promise<Void> {
    return Promise { seal in
      let addressString = metaAddress.address
      let index = metaAddress.derivationPath.index

      context.performAndWait {
        let newAddress = CKMServerAddress(address: addressString, createdAt: createdAt, insertInto: context)
        newAddress.derivativePath = CKMDerivativePath.findOrCreate(withIndex: Int(index), in: context)
      }

      seal.fulfill(()) //no need to return the created object(s), fulfill with Void
    }
  }

  func persistTransactions(
    from transactionResponses: [TransactionResponse],
    in context: NSManagedObjectContext,
    relativeToCurrentHeight blockHeight: Int,
    fullSync: Bool
    ) -> Promise<Void> {
    return Promise { seal in
      transactionResponses.forEach {
        _ = CKMTransaction.findOrCreate(with: $0, in: context, relativeToBlockHeight: blockHeight, fullSync: fullSync)
      }
      seal.fulfill(())
    }
  }

  func persistTransactionSummaries(
    from responses: [AddressTransactionSummaryResponse],
    in context: NSManagedObjectContext) {

    responses.forEach { response in
      let ats = CKMAddressTransactionSummary.findOrCreate(with: response, in: context)

      if let pathResponse = response.derivativePathResponse, ats.isChangeAddress != pathResponse.isChangeAddress {
        ats.isChangeAddress = pathResponse.isChangeAddress
      }
    }
  }

  func persistTemporaryTransaction(
    from transactionData: CNBTransactionData,
    with outgoingTransactionData: OutgoingTransactionData,
    txid: String,
    invitation: CKMInvitation?,
    in context: NSManagedObjectContext
    ) -> CKMTransaction {

    var outgoingTxDTO = outgoingTransactionData
    outgoingTxDTO.txid = txid
    outgoingTxDTO.feeAmount = Int(transactionData.feeAmount)

    invitation?.setTxid(to: txid)
    invitation?.status = .completed

    func updateOrCreateTxForTempTx() -> CKMTransaction {
      if let existingTransaction = CKMTransaction.find(byTxid: txid, in: context),
        let invitation = invitation,
        invitation.transaction !== existingTransaction {

        let txToRemove = invitation.transaction
        invitation.transaction = existingTransaction
        txToRemove.map { context.delete($0) }
        existingTransaction.phoneNumber = invitation.counterpartyPhoneNumber
        return existingTransaction

      } else if let invitation = invitation, let tx = invitation.transaction {
        tx.configure(with: outgoingTxDTO, in: context)
        tx.phoneNumber = invitation.counterpartyPhoneNumber
        return tx

      } else {
        let transaction = CKMTransaction(insertInto: context)
        transaction.configure(with: outgoingTxDTO, in: context)
        return transaction
      }
    }

    // Identify relevantTx to link vouts to its tempTx
    let relevantTransaction = updateOrCreateTxForTempTx()
    relevantTransaction.configureNewSenderSharedPayload(with: outgoingTxDTO.sharedPayloadDTO, in: context)

    // Currently, this function is only called after broadcastTx()
    relevantTransaction.broadcastedAt = Date()

    let vouts = transactionData.unspentTransactionOutputs.compactMap { CKMVout.find(from: $0, in: context) }

    // Link the vout to the relevant tempTx in case we need to mark the tx as failed and free up these vouts
    relevantTransaction.temporarySentTransaction?.reservedVouts = Set(vouts)

    vouts.forEach { $0.isSpent = true }

    return relevantTransaction
  }

  func deleteTransactions(notIn txids: [String], in context: NSManagedObjectContext) {
    let transactionsToRemove = CKMTransaction.findAllToDelete(notIn: txids, in: context)
    transactionsToRemove.forEach { context.delete($0) }
  }

  func latestTransaction(in context: NSManagedObjectContext) -> CKMTransaction? {
    return CKMTransaction.findLatest(in: context)
  }

  func getAllInvitations(in context: NSManagedObjectContext) -> [CKMInvitation] {
    return CKMInvitation.getAllInvitations(in: context)
  }

  func getUnacknowledgedInvitations(in context: NSManagedObjectContext) -> [CKMInvitation] {
    return CKMInvitation.findUnacknowledgedInvitations(in: context)
  }

  func transactionsWithoutDayAveragePrice(in context: NSManagedObjectContext) -> Promise<[CKMTransaction]> {
    let pricePredicate = CKPredicate.Transaction.withoutDayAveragePrice()
    let txidPredicate = CKPredicate.Transaction.withValidTxid()
    let compoundPredicate = NSCompoundPredicate(type: .and, subpredicates: [pricePredicate, txidPredicate])

    return Promise { seal in
      let request: NSFetchRequest<CKMTransaction> = CKMTransaction.fetchRequest()
      request.predicate = compoundPredicate
      let results = try context.fetch(request)
      seal.fulfill(results)
    }
  }

  func serverPoolAddresses(in context: NSManagedObjectContext) -> [CKMServerAddress] {
    let request: NSFetchRequest<CKMServerAddress> = CKMServerAddress.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CKMServerAddress.derivativePath.index), ascending: true)]
    let results = try? context.fetch(request)
    return results ?? []
  }

  func updateLastReceiveAddressIndex(index: Int?, in context: NSManagedObjectContext) {
    context.performAndWait {
      CKMWallet.find(in: context)?.lastReceivedIndex = index ?? CKMWallet.defaultLastIndex
    }
  }

  func updateLastChangeAddressIndex(index: Int?, in context: NSManagedObjectContext) {
    context.performAndWait {
      CKMWallet.find(in: context)?.lastChangeIndex = index ?? CKMWallet.defaultLastIndex
    }
  }

  func addressesProvidedForReceivedPendingDropBits(in context: NSManagedObjectContext) -> [String] {
    return CKMInvitation.addressesProvidedForReceivedPendingDropBits(in: context)
  }

  /// CKMWallet stores -1 as the default, non-optional value. This function returns nil if the stored value is negative.
  func lastReceiveIndex(in context: NSManagedObjectContext) -> Int? {
    var value: Int?
    context.performAndWait {
      if let lastIndex = CKMWallet.find(in: context)?.lastReceivedIndex, lastIndex >= 0 {
        value = lastIndex
      }
    }
    return value
  }

  /// CKMWallet stores -1 as the default, non-optional value. This function returns nil if the stored value is negative.
  func lastChangeIndex(in context: NSManagedObjectContext) -> Int? {
    var value: Int?
    context.performAndWait {
      if let lastIndex = CKMWallet.find(in: context)?.lastChangeIndex, lastIndex >= 0 {
        value = lastIndex
      }
    }
    return value
  }

  func matchContactsIfPossible(with contactCacheManager: ContactCacheManagerType) {
    let context = self.createBackgroundContext()
    context.perform {
      self.performContactMatch(with: contactCacheManager, in: context)
    }
  }

  func performContactMatch(with contactCacheManager: ContactCacheManagerType, in context: NSManagedObjectContext) {
    let nonMatchingPhoneNumbers = CKMPhoneNumber.findAllWithoutCounterpartyName(in: context)
    let nonMatchingGlobalPhoneNumbers = nonMatchingPhoneNumbers
      .map { GlobalPhoneNumber(countryCode: Int($0.countryCode), nationalNumber: String($0.number)) }
    let matchingMetadata = nonMatchingGlobalPhoneNumbers
      .compactMap { contactCacheManager.managedContactComponents(forGlobalPhoneNumber: $0) }
      .filter { $0.counterpartyInputs.name.isNotEmpty }
    matchingMetadata.forEach { metadata in
      let numberToUpdate = nonMatchingPhoneNumbers
        .first { $0.asGlobalPhoneNumber == metadata.phonenumberInputs.asGlobalPhoneNumber() }
      numberToUpdate?.counterparty = CKMCounterparty.findOrCreate(with: metadata.counterpartyInputs.name, in: context)
    }

    if context.hasChanges {
      do {
        try context.save()
      } catch {
        log.contextSaveError(error)
      }
    }
  }
}
