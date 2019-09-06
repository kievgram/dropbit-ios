//
//  TransactionHistoryViewController.swift
//  DropBit
//
//  Created by Ben Winters on 4/6/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import CoreData
import UIKit
import CNBitcoinKit
import Gifu
import PromiseKit
import DZNEmptyDataSet

protocol TransactionHistoryViewControllerDelegate: DeviceCountryCodeProvider &
  BadgeUpdateDelegate & URLOpener & LightningReloadDelegate & CurrencyValueDataSourceType {
  func viewControllerDidRequestHistoryUpdate(_ viewController: TransactionHistoryViewController)
  func viewControllerDidDisplayTransactions(_ viewController: TransactionHistoryViewController)
  func viewControllerAttemptedToRefreshTransactions(_ viewController: UIViewController)

  func viewControllerDidRequestTutorial(_ viewController: UIViewController)
  func viewControllerDidTapGetBitcoin(_ viewController: UIViewController)
  func viewControllerDidTapSpendBitcoin(_ viewController: UIViewController)

  var currencyController: CurrencyController { get }
  func viewControllerSummariesDidReload(_ viewController: TransactionHistoryViewController, indexPathsIfNotAll paths: [IndexPath]?)
  func viewController(_ viewController: TransactionHistoryViewController, didSelectItemAtIndexPath indexPath: IndexPath)
  func viewControllerDidDismissTransactionDetails(_ viewController: UIViewController)

  /// Return nil to hide header
  func summaryHeaderType(for viewController: UIViewController) -> SummaryHeaderType?
  func viewControllerDidSelectSummaryHeader(_ viewController: UIViewController)
}

class TransactionHistoryViewController: BaseViewController, StoryboardInitializable {

  @IBOutlet var emptyStateBackgroundView: UIView!
  @IBOutlet var emptyStateBackgroundTopConstraint: NSLayoutConstraint!
  @IBOutlet var summaryCollectionView: TransactionHistorySummaryCollectionView!
  @IBOutlet var transactionHistoryNoBalanceView: TransactionHistoryNoBalanceView!
  @IBOutlet var transactionHistoryWithBalanceView: TransactionHistoryWithBalanceView!
  @IBOutlet var lightningTransactionHistoryEmptyBalanceView: LightningTransactionHistoryEmptyView!
  @IBOutlet var refreshView: TransactionHistoryRefreshView!
  @IBOutlet var refreshViewTopConstraint: NSLayoutConstraint!
  @IBOutlet var footerView: UIView!
  @IBOutlet var gradientBlurView: UIView! {
    didSet {
      gradientBlurView.backgroundColor = .white
      gradientBlurView.fade(style: .top, percent: 1.0)
    }
  }

  var viewModel: TransactionHistoryViewModel!
  var selectedCurrency: SelectedCurrency = .fiat

  static func newInstance(withDelegate delegate: TransactionHistoryViewControllerDelegate,
                          walletTxType: WalletTransactionType,
                          dataSource: TransactionHistoryDataSourceType) -> TransactionHistoryViewController {
    let viewController = TransactionHistoryViewController.makeFromStoryboard()
    viewController.generalCoordinationDelegate = delegate
    dataSource.delegate = viewController
    viewController.viewModel = TransactionHistoryViewModel(delegate: viewController,
                                                           currencyManager: delegate,
                                                           deviceCountryCode: delegate.deviceCountryCode(),
                                                           transactionType: walletTxType,
                                                           dataSource: dataSource)
    return viewController
  }

  var isCollectionViewFullScreen: Bool = false {
    willSet {
      footerView.isHidden = !newValue
      gradientBlurView.isHidden = !newValue
    }
  }

  override func accessibleViewsAndIdentifiers() -> [AccessibleViewElement] {
    return [
      (self.view, .transactionHistory(.page)),
      (transactionHistoryNoBalanceView.learnAboutBitcoinButton, .transactionHistory(.tutorialButton))
    ]
  }

  var coordinationDelegate: TransactionHistoryViewControllerDelegate! {
    return generalCoordinationDelegate as? TransactionHistoryViewControllerDelegate
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    transactionHistoryNoBalanceView.delegate = self
    transactionHistoryWithBalanceView.delegate = self
    lightningTransactionHistoryEmptyBalanceView.delegate = coordinationDelegate
    emptyStateBackgroundView.isHidden = false
    emptyStateBackgroundView.backgroundColor = .whiteBackground

    view.backgroundColor = .clear
    emptyStateBackgroundView.applyCornerRadius(30, toCorners: .top)
    coordinationDelegate?.viewControllerDidRequestBadgeUpdate(self)

    CKNotificationCenter.subscribe(self, key: .didUpdateWordsBackedUp, selector: #selector(didUpdateWordsBackedUp))

    setupCollectionViews()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: true)
    resetCollectionView()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // In case new transactions came it while this view was open, this will hide the badge
    coordinationDelegate?.viewControllerDidDisplayTransactions(self)
  }

  internal func reloadTransactions(atIndexPaths paths: [IndexPath]) {
    summaryCollectionView.reloadItems(at: paths)
    coordinationDelegate?.viewControllerSummariesDidReload(self, indexPathsIfNotAll: paths)
  }

}

extension TransactionHistoryViewController { // Layout

  func showDetailCollectionView(_ shouldShow: Bool, indexPath: IndexPath, animated: Bool) {
    if shouldShow {
      coordinationDelegate?.viewController(self, didSelectItemAtIndexPath: indexPath)
    } else {
      coordinationDelegate?.viewControllerDidDismissTransactionDetails(self)
    }
  }

  /// 20 for most devices, 44 on iPhone X
  private var statusBarHeight: CGFloat {
    return UIApplication.shared.statusBarFrame.height
  }

}

extension TransactionHistoryViewController: TransactionHistoryDataSourceDelegate {
  func transactionDataSourceWillChange() {
    transactionHistoryWithBalanceView.isHidden = true
    transactionHistoryNoBalanceView.isHidden = true
    lightningTransactionHistoryEmptyBalanceView.isHidden = true
  }

  func transactionDataSourceDidChange() {
    reloadCollectionViews()
  }

  @objc func didUpdateWordsBackedUp() {
    transactionDataSourceDidChange()
  }

}

extension TransactionHistoryViewController: NoTransactionsViewDelegate {
  func noTransactionsViewDidSelectGetBitcoin(_ view: TransactionHistoryEmptyView) {
    coordinationDelegate?.viewControllerDidTapGetBitcoin(self)
  }

  func noTransactionsViewDidSelectSpendBitcoin(_ view: TransactionHistoryEmptyView) {
    coordinationDelegate?.viewControllerDidTapSpendBitcoin(self)
  }

  func noTransactionsViewDidSelectLearnAboutBitcoin(_ view: TransactionHistoryEmptyView) {
    coordinationDelegate?.viewControllerDidRequestTutorial(self)
  }
}

extension TransactionHistoryViewController: SelectedCurrencyUpdatable {
  func updateSelectedCurrency(to selectedCurrency: SelectedCurrency) {
    let summaryIndexSet = IndexSet(integersIn: (0..<summaryCollectionView.numberOfSections))
    summaryCollectionView.reloadSections(summaryIndexSet)
    coordinationDelegate?.viewControllerSummariesDidReload(self, indexPathsIfNotAll: nil)
  }
}

extension TransactionHistoryViewController: TransactionHistoryViewModelDelegate {

  var currencyController: CurrencyController {
    return coordinationDelegate.currencyController
  }

  func viewModelDidUpdateExchangeRates() {
    reloadCollectionViews()
  }

  func summaryHeaderType() -> SummaryHeaderType? {
    return coordinationDelegate.summaryHeaderType(for: self)
  }

  func didTapSummaryHeader(_ header: TransactionHistorySummaryHeader) {
    self.coordinationDelegate.viewControllerDidSelectSummaryHeader(self)
  }

}

extension TransactionHistoryViewController: DZNEmptyDataSetDelegate, DZNEmptyDataSetSource {

  func emptyDataSetShouldBeForced(toDisplay scrollView: UIScrollView!) -> Bool {
    return viewModel.shouldShowEmptyDataSet
  }

  func emptyDataSetShouldDisplay(_ scrollView: UIScrollView!) -> Bool {
    let offset = verticalOffset(forEmptyDataSet: scrollView)
    emptyStateBackgroundTopConstraint.constant = summaryCollectionView.topInset + offset
    return viewModel.shouldShowEmptyDataSet
  }

  func emptyDataSetShouldAllowTouch(_ scrollView: UIScrollView!) -> Bool {
    return true
  }

  func customView(forEmptyDataSet scrollView: UIScrollView!) -> UIView! {
    if viewModel.shouldShowNoBalanceEmptyDataSetView {
      transactionHistoryNoBalanceView.isHidden = false
      return transactionHistoryNoBalanceView
    } else if viewModel.shouldShowWithBalanceEmptyDataSetView {
      transactionHistoryWithBalanceView.isHidden = false
      return transactionHistoryWithBalanceView
    } else if viewModel.shouldShowLightningEmptyDataSetView {
      lightningTransactionHistoryEmptyBalanceView.isHidden = false
      return lightningTransactionHistoryEmptyBalanceView
    } else {
      return nil
    }
  }

  func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
    let headerIsShown = coordinationDelegate.summaryHeaderType(for: self) != nil
    let headerHeight = headerIsShown ? self.viewModel.warningHeaderHeight : 0
    let cellHeight = viewModel.shouldShowWithBalanceEmptyDataSetView ? SummaryCollectionView.cellHeight : 0

    let contentOffset = (headerHeight + cellHeight) / 2
    let paddedOffset = (contentOffset > 0) ? (contentOffset + 20) : 0

    return paddedOffset
  }

}
