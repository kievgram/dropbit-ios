//
//  WorkerFactory.swift
//  DropBit
//
//  Created by Ben Winters on 5/15/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import CoreData

/// The actual wallet manager object may change its seed words during the course of the app,
/// so we request the current instance of it each time through this provider.
protocol WalletManagerProvider: AnyObject {
  var walletManager: WalletManagerType? { get }
}

extension AppCoordinator: WalletManagerProvider { }

class WorkerFactory {

  let persistenceManager: PersistenceManagerType
  let networkManager: NetworkManagerType
  let analyticsManager: AnalyticsManagerType
  weak var wmgrProvider: WalletManagerProvider?
  weak var paymentSendingDelegate: AllPaymentSendingDelegate?

  init(persistenceManager: PersistenceManagerType,
       networkManager: NetworkManagerType,
       analyticsManager: AnalyticsManagerType,
       walletManagerProvider: WalletManagerProvider,
       paymentSendingDelegate: AllPaymentSendingDelegate) {
    self.persistenceManager = persistenceManager
    self.networkManager = networkManager
    self.analyticsManager = analyticsManager
    self.wmgrProvider = walletManagerProvider
    self.paymentSendingDelegate = paymentSendingDelegate
  }

  /// This function ensures we are always working with the current instance of the WalletManager
  func createTransactionDataWorker() -> TransactionDataWorker? {
    guard let wmgr = wmgrProvider?.walletManager else { return nil }
    return TransactionDataWorker(walletManager: wmgr,
                                 persistenceManager: persistenceManager,
                                 networkManager: networkManager,
                                 analyticsManager: analyticsManager)
  }

  /// This function ensures we are always working with the current instance of the WalletManager
  func createWalletAddressDataWorker(delegate: InvitationWorkerDelegate) -> WalletAddressDataWorker? {
    guard let wmgr = wmgrProvider?.walletManager, let paymentDelegate = paymentSendingDelegate else { return nil }
    return WalletAddressDataWorker(walletManager: wmgr,
                                   persistenceManager: persistenceManager,
                                   networkManager: networkManager,
                                   analyticsManager: analyticsManager,
                                   paymentSendingDelegate: paymentDelegate,
                                   invitationWorkerDelegate: delegate)
  }

  func createKeychainMigrationWorker() -> KeychainMigrationWorker {
    let factory = KeychainMigratorFactory(persistenceManager: persistenceManager)
    return KeychainMigrationWorker(migrators: factory.migrators())
  }

  func createMigratorFactory(in context: NSManagedObjectContext) -> DatabaseMigratorFactory? {
    guard let wmgr = wmgrProvider?.walletManager else { return nil }
    let addressDataSource = wmgr.createAddressDataSource()
    return DatabaseMigratorFactory(persistenceManager: persistenceManager, addressDataSource: addressDataSource, context: context)
  }

  func createDatabaseMigrationWorker(in context: NSManagedObjectContext) -> DatabaseMigrationWorker? {
    guard let factory = createMigratorFactory(in: context) else { return nil }
    let migrators = factory.migrators()
    return DatabaseMigrationWorker(migrators: migrators, in: context)
  }

}
