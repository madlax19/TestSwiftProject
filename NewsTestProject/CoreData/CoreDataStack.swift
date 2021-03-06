//
//  CoreDataStack.swift
//  NewsTestProject
//
//  Created by Sergei on 3/24/18.
//  Copyright © 2018 Sergei. All rights reserved.
//

import Foundation
import CoreData

protocol CoreDataStack {
    var persistentContainer: NSPersistentContainer { get }
    var context: NSManagedObjectContext { get }
    
    func performSingleSave<T>(with privateContext:((NSManagedObjectContext) -> T?)?, completion:((T?) -> Void)?) where T : NSManagedObject
    func performMultipleSaving<T>(with privateContext:((NSManagedObjectContext) -> [T]?)?, completion:(([T]?) -> Void)?) where T : NSManagedObject
    
    func saveContext()
}

final class CoreDataStackImp: CoreDataStack {
    
    private(set) var persistentContainer:NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.persistentContainer = container
        self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    static let `default`: CoreDataStackImp = {
        let container = NSPersistentContainer(name: "NewsTestProject")
        container.loadPersistentStores(completionHandler: { (d, error) in
            if let error = error {
                debugPrint("Unresolved error: ",error)
            }
        })
        return CoreDataStackImp(container: container)
    }()
    
    lazy var context: NSManagedObjectContext = {
        return persistentContainer.viewContext
    }()
    
    func performSingleSave<T>(with privateContext:((NSManagedObjectContext) -> T?)?, completion:((T?) -> Void)?) where T : NSManagedObject {

        let mainCtx = context
        persistentContainer.performBackgroundTask { (privateCtx) in
            if let object = privateContext?(privateCtx) {
                try! privateCtx.save()
                let objectID = object.objectID
                mainCtx.performAndWait {
                    do {
                        try mainCtx.save()
                        if let savedObject = try mainCtx.existingObject(with: objectID) as? T {
                            completion?(savedObject)
                        }
                    } catch _ {
                        completion?(nil)
                    }
                }
            } else {
                completion?(nil)
            }
        }
    }
    
    func performMultipleSaving<T>(with privateContext:((NSManagedObjectContext) -> [T]?)?, completion:(([T]?) -> Void)?) where T : NSManagedObject {
        
        let mainCtx = context
        persistentContainer.performBackgroundTask { (privateCtx) in
            if let objects = privateContext?(privateCtx), objects.count > 0 {
                try! privateCtx.save()
                let objectIDs = objects.map { $0.objectID }
                mainCtx.perform {
                    do {
                        try mainCtx.save()
                        let objects = try objectIDs.flatMap({
                            try mainCtx.existingObject(with: $0) as? T
                        })
                        completion?(objects)
                    } catch _ {
                        completion?(nil)
                    }
                }
            } else {
                completion?(nil)
            }
        }
    }
    
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch let error {
                debugPrint("CoreData save error:", error)
            }
        }
    }
    
}
