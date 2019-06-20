//
//  MockAlertManager.swift
//  DropBitTests
//
//  Created by Ben Winters on 6/19/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

import Foundation
import UIKit
@testable import DropBit

class MockAlertManager: AlertManagerType {
  var urlOpener: URLOpener?

  func showBanner(with message: String, duration: AlertDuration?) {}

  func alert(from viewModel: AlertControllerViewModel) -> AlertControllerType {
    return alert(withTitle: viewModel.title,
                 description: viewModel.description,
                 image: viewModel.image,
                 style: viewModel.style,
                 actionConfigs: viewModel.actions)
  }

  var showBannerWithMessageDurationAlertKindWasCalled = false
  func showBanner(with message: String, duration: AlertDuration?, alertKind kind: CKBannerViewKind) {
    showBannerWithMessageDurationAlertKindWasCalled = true
  }
  func showBannerAlert(for response: MessageResponse, completion: (() -> Void)?) {}

  func defaultAlert(withTitle title: String, description: String?) -> AlertControllerType {
    let alertManager = AlertManager(notificationManager:
      NotificationManager(permissionManager: PermissionManager(),
                          networkInteractor: NetworkManager(persistenceManager: PersistenceManager(),
                                                            analyticsManager: AnalyticsManager())))
    return alertManager.alert(withTitle: title, description: description, image: nil, style: .alert, actionConfigs: [])
  }

  func showBanner(with message: String, duration: AlertDuration) { }
  func showBanner(with message: String, duration: AlertDuration, alertKind kind: CKBannerViewKind) { }
  func showBanner(with message: String, alertKind kind: CKBannerViewKind) { }
  func showBanner(with message: String, duration: AlertDuration?, alertKind kind: CKBannerViewKind, tapAction: (() -> Void)?) {}
  func showAlert(for update: AddressRequestUpdateDisplayable) { }

  func alert(withTitle title: String,
             description: String?,
             image: UIImage?,
             style: AlertManager.AlertStyle,
             buttonLayout: AlertManagerButtonLayout,
             actionConfigs: [AlertActionConfigurationType]) -> AlertControllerType {
    let alertManager = AlertManager(notificationManager:
      NotificationManager(permissionManager: PermissionManager(),
                          networkInteractor: NetworkManager(persistenceManager: PersistenceManager(),
                                                            analyticsManager: AnalyticsManager())))
    return alertManager.alert(withTitle: title, description: description, image: image, style: style, actionConfigs: [])
  }

  func detailedAlert(withTitle title: String?,
                     description: String?,
                     image: UIImage,
                     style: AlertMessageStyle,
                     action: AlertActionConfigurationType
    ) -> AlertControllerType {
    let alertManager = AlertManager(notificationManager:
      NotificationManager(permissionManager: PermissionManager(),
                          networkInteractor: NetworkManager(persistenceManager: PersistenceManager(),
                                                            analyticsManager: AnalyticsManager())))
    return alertManager.detailedAlert(withTitle: title, description: description, image: image, style: style, action: action)
  }

  func didTapBanner(_ bannerView: CKBannerView) {}
  func didTapClose(_ bannerView: CKBannerView) {}

  var wasAskedForAlert = false
  func alert(withTitle title: String,
             description: String?,
             image: UIImage?,
             style: AlertManager.AlertStyle,
             actionConfigs: [AlertActionConfigurationType]) -> AlertControllerType {

    wasAskedForAlert = true
    let alertManager = AlertManager(notificationManager:
      NotificationManager(permissionManager: PermissionManager(),
                          networkInteractor: NetworkManager(persistenceManager: PersistenceManager(),
                                                            analyticsManager: AnalyticsManager())))
    return alertManager.alert(withTitle: title, description: description, image: image, style: style, actionConfigs: [])
  }

  var notificationManager: NotificationManagerType

  required init(notificationManager: NotificationManagerType) {
    self.notificationManager = notificationManager
  }

  var wasAskedToShowSuccessMessage = false
  func showSuccess(message: String, forDuration duration: TimeInterval?) {
    wasAskedToShowSuccessMessage = true
  }

  func showError(message: String, forDuration duration: TimeInterval?) {
  }

  var wasAskedToShowActivityHUD = false
  func showActivityHUD(withStatus status: String?) {
    wasAskedToShowActivityHUD = true
  }

  var wasAskedToHideActivityHUD = false
  func hideActivityHUD(withDelay delay: TimeInterval?, completion: (() -> Void)?) {
    wasAskedToHideActivityHUD = true
  }

  func showSuccessHUD(withStatus status: String?, duration: TimeInterval, completion: (() -> Void)?) { }

  func showIncomingTransactionAlert(for receivedAmount: Int, with rates: ExchangeRates) { }

}
