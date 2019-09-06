//
//  AppCoordinator+BalanceContainerDelegate.swift
//  DropBit
//
//  Created by BJ Miller on 4/24/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import UIKit
import CoreData
import PromiseKit

extension AppCoordinator: BalanceContainerDelegate {

  func selectedWallet() -> WalletTransactionType {
    return persistenceManager.brokers.preferences.selectedWalletTransactionType
  }

  func isSyncCurrentlyRunning() -> Bool {
    let syncOperations = serialQueueManager.queue.operations(ofType: .syncWallet(.standard),
                                                             ignoringAssociatedType: true)
    return syncOperations.isNotEmpty
  }

  func containerDidTapLeftButton(in viewController: UIViewController) {
    self.drawerController?.toggle(.left, animated: true, completion: nil)
  }

  func containerDidTapDropBitMe(in viewController: UIViewController) {
    presentDropBitMeViewController(verifiedFirstTime: false)
  }

  func didTapChartsButton() {
    guard let topVC = self.navigationController.topViewController() else { return }
    let newsViewController = NewsViewController.makeFromStoryboard()
    assignCoordinationDelegate(to: newsViewController)
    topVC.present(newsViewController, animated: true, completion: nil)
  }

  func presentDropBitMeViewController(verifiedFirstTime: Bool) {
    guard let topVC = self.navigationController.topViewController() else { return }

    let context = self.persistenceManager.viewContext
    let avatarData = CKMUser.find(in: context)?.avatar
    let publicURLInfo: UserPublicURLInfo? = self.persistenceManager.brokers.user.getUserPublicURLInfo(in: context)
    let config = DropBitMeConfig(publicURLInfo: publicURLInfo, verifiedFirstTime: verifiedFirstTime, userAvatarData: avatarData)

    let dropBitMeVC = DropBitMeViewController.newInstance(config: config, delegate: self)
    topVC.present(dropBitMeVC, animated: true, completion: nil)
  }

  func didTapRightBalanceView(in viewController: UIViewController) {
    if let controller = viewController as? WalletOverviewViewController {
      // save to user defaults
      currencyController.selectedCurrency.toggle()
      persistenceManager.brokers.preferences.selectedCurrency = currencyController.selectedCurrency

      // tell tx history to reload from user defaults
      controller.updateSelectedCurrency(to: currencyController.selectedCurrency)
    }
  }

  func dropBitMeAvatar() -> Promise<UIImage> {
    let defaultImage = UIImage(imageLiteralResourceName: "dropBitMeAvatarPlaceholder")
    let context = persistenceManager.viewContext

    if let user = CKMUser.find(in: context) {
      if let avatar = user.avatar {
        let image = UIImage(data: avatar) ?? defaultImage
        return Promise.value(image)
      } else if persistenceManager.brokers.user.userIsVerified(using: .twitter, in: context) {
        return twitterAccessManager.getCurrentTwitterUser()
          .then { (user: TwitterUser) -> Promise<UIImage> in
            let image = user.profileImageData.flatMap { UIImage(data: $0) } ?? defaultImage
            return Promise.value(image)
          }
      } else {
        return Promise.value(defaultImage)
      }
    } else {
      return Promise.value(defaultImage)
    }
  }

}

extension AppCoordinator {

  fileprivate func deleteAllTransactionsAndRelatedObjects(in context: NSManagedObjectContext) {
    CKMTransaction.deleteAll(in: context)
    CKMPhoneNumber.deleteAll(in: context)
    CKMAddressTransactionSummary.deleteAll(in: context)
    CKMCounterpartyAddress.deleteAll(in: context)
    CKMAddress.deleteAll(in: context)
  }

  func selectedCurrency() -> SelectedCurrency {
    return currencyController.selectedCurrency
  }
}
