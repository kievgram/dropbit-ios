//
//  ContactType.swift
//  CoinKeeper
//
//  Created by Mitchell on 5/31/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//

import Foundation

enum ContactKind {
  case generic
  case registeredUser
  case invite
}

protocol ContactType {
  var kind: ContactKind { get set }
  var displayName: String? { get }
  var displayIdentity: String { get }
  var userIdentityBody: UserIdentityBody { get }
}

extension ContactType {
  var identityType: UserIdentityType {
    return userIdentityBody.identityType
  }

  var identityHash: String {
    return userIdentityBody.identityHash
  }
}

protocol PhoneContactType: ContactType {
  var displayNumber: String { get }
  var phoneNumberHash: String { get }
  var globalPhoneNumber: GlobalPhoneNumber { get }
}

extension PhoneContactType {
  var phoneNumberHash: String {
    return globalPhoneNumber.hashed()
  }

  var userIdentityBody: UserIdentityBody {
    return UserIdentityBody(phoneNumber: globalPhoneNumber)
  }

  var displayIdentity: String {
    return displayNumber
  }
}

protocol TwitterContactType: ContactType {
  var displayHandle: String { get }
  var identityHash: String { get }
  var twitterUser: TwitterUser { get }
}

struct ValidatedContact: PhoneContactType {

  var kind: ContactKind
  let displayName: String?
  let displayNumber: String
  let globalPhoneNumber: GlobalPhoneNumber

  init?(cachedNumber: CCMPhoneNumber) {
    guard let metadata = cachedNumber.cachedValidatedMetadata,
      let displayName = cachedNumber.cachedContact?.displayName
      else { return nil }

    switch cachedNumber.verificationStatus {
    case .verified:     self.kind = .registeredUser
    case .notVerified:  self.kind = .invite
    }

    self.displayName = displayName
    self.displayNumber = cachedNumber.displayNumber
    self.globalPhoneNumber = GlobalPhoneNumber(countryCode: metadata.countryCode, nationalNumber: metadata.nationalNumber)
  }

}

struct GenericContact: PhoneContactType {

  var kind: ContactKind
  var displayName: String?
  var displayNumber: String
  var globalPhoneNumber: GlobalPhoneNumber

  init(phoneNumber: GlobalPhoneNumber, hash: String, formatted: String) {
    self.kind = .generic
    self.displayName = nil
    self.displayNumber = formatted
    self.globalPhoneNumber = phoneNumber
  }

}

struct TwitterContact: TwitterContactType {
  var kind: ContactKind = .invite
  var twitterUser: TwitterUser

  var userIdentityBody: UserIdentityBody {
    return UserIdentityBody(twitterUser: twitterUser)
  }

  var displayHandle: String {
    return twitterUser.formattedScreenName
  }

  var identityHash: String {
    return twitterUser.idStr
  }

  var displayName: String? {
    return twitterUser.name
  }

  var displayIdentity: String {
    return displayHandle
  }

  init(twitterUser: TwitterUser) {
    self.twitterUser = twitterUser
  }
}
