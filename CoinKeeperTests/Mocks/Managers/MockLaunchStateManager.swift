//
//  MockLaunchStateManager.swift
//  DropBitTests
//
//  Created by BJ Miller on 2/26/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

@testable import DropBit

class MockLaunchStateManager: LaunchStateManagerType {

  var launchType: LaunchType = .userInitiated
  var selectedSetupFlow: SetupFlow?
  var upgradeInProgress: Bool = false

  var shouldNeedUpgradeToSegwit = false
  func needsUpgradedToSegwit() -> Bool {
    return shouldNeedUpgradeToSegwit
  }

  func isUpgradedToSegwit() -> Bool {
    return false
  }

  func currentProperties() -> LaunchStateProperties {
    return []
  }

  var userAuthenticatedValue = false
  var userAuthenticated: Bool {
    return userAuthenticatedValue
  }

  var skippedVerificationValue = false
  var skippedVerification: Bool {
    return skippedVerificationValue
  }

  func isFirstTime() -> Bool {
    return true
  }

  func isFirstTimeAfteriCloudRestore() -> Bool {
    return false
  }

  func shouldRegisterWallet() -> Bool {
    return false
  }

  var walletExistsValue = false
  func walletExists() -> Bool {
    return walletExistsValue
  }

  var isWalletBackedUp = false
  func walletIsBackedUp() -> Bool {
    return isWalletBackedUp
  }

  var pinExistsValue = false
  func pinExists() -> Bool {
    return pinExistsValue
  }

  var wasAskedForShouldRequireAuthentication = false
  var mockShouldRequireAuthentication = false
  var shouldRequireAuthentication: Bool {
    wasAskedForShouldRequireAuthentication = true
    return mockShouldRequireAuthentication
  }

  var wasAskedForShouldRequireDeviceVerification = false
  var mockShouldRequireDeviceVerification = false
  var shouldRequireDeviceVerification: Bool {
    wasAskedForShouldRequireDeviceVerification = true
    return mockShouldRequireDeviceVerification
  }

  required init(persistenceManager: PersistenceManagerType) {}

  var userWasAuthenticatedWasCalled = false
  func userWasAuthenticated() {
    userWasAuthenticatedWasCalled = true
  }

  var unauthenticateUserWasCalled = false
  func unauthenticateUser() {
    unauthenticateUserWasCalled = true
  }

  var deviceWasVerifiedWasCalled = false
  func deviceWasVerified() {
    deviceWasVerifiedWasCalled = true
  }

  var unverifyDeviceWasCalled = false
  func unverifyDevice() {
    unverifyDeviceWasCalled = true
  }

  func profileIsActivated() -> Bool {
    return false
  }

  var deviceIsVerifiedValue = false
  func deviceIsVerified() -> Bool {
    return deviceIsVerifiedValue
  }

}
