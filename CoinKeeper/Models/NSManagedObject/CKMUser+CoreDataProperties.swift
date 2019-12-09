//
//  CKMUser+CoreDataProperties.swift
//  DropBit
//
//  Created by Ben Winters on 5/11/18.
//  Copyright © 2018 Coin Ninja, LLC. All rights reserved.
//
//

import Foundation
import CoreData

@objc public enum HolidayType: Int16 {
  case bitcoin = 1
  case holiday = 2
  case christmas = 3
  case hanukkah = 4
}

extension CKMUser {

  @nonobjc public class func fetchRequest() -> NSFetchRequest<CKMUser> {
    return NSFetchRequest<CKMUser>(entityName: "CKMUser")
  }

  @NSManaged public var id: String
  @NSManaged public var holidayType: HolidayType //default 1
  @NSManaged public var verificationStatus: String?
  @NSManaged public var publicURLIsPrivate: Bool
  @NSManaged public var avatar: Data?
  @NSManaged public var wallet: CKMWallet?
}
