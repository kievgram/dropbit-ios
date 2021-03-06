//
//  MockContactCacheManager.swift
//  DropBit
//
//  Created by Ben Winters on 2/20/19.
//  Copyright © 2019 Coin Ninja, LLC. All rights reserved.
//

@testable import DropBit
import Foundation
import CoreData
import Contacts

class MockContactCacheManager: ContactCacheManagerType {

  let stack = InMemoryCoreDataStack(stackConfig: CoreDataStackConfig(stackType: .contactCache, storeType: .inMemory))

  var viewContext: NSManagedObjectContext {
    return stack.context
  }

  func createBackgroundContext() -> NSManagedObjectContext {
    return NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
  }

  func createRootBackgroundContext() -> NSManagedObjectContext {
    return NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
  }

  func createPhoneNumberFetchedResultsController() -> NSFetchedResultsController<CCMPhoneNumber> {
    return NSFetchedResultsController<CCMPhoneNumber>()
  }

  func predicate(forSearch searchText: String) -> NSPredicate {
    return NSPredicate(value: true)
  }

  func allValidatedMetadata(in context: NSManagedObjectContext) throws -> [CCMValidatedMetadata] {
    return []
  }

  func allCachedContacts(in context: NSManagedObjectContext) throws -> [CCMContact] {
    return []
  }

  func phoneNumberCount(in context: NSManagedObjectContext) throws -> Int {
    return 0
  }

  func deleteSystemContactData(in context: NSManagedObjectContext) throws { }

  func persistContacts(_ contacts: [CNContact],
                       inputs: CachedPhoneNumberDependencies,
                       progress: ContactProgressHandler?,
                       in context: NSManagedObjectContext) throws { }

  func validatedMetadata(for globalPhoneNumber: GlobalPhoneNumber, in context: NSManagedObjectContext) -> CCMValidatedMetadata? {
    return nil
  }

  func managedContactComponents(forGlobalPhoneNumber number: GlobalPhoneNumber, in context: NSManagedObjectContext) -> ManagedContactComponents? {
    return nil
  }

}
