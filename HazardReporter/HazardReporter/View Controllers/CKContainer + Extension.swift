//
//  CKContainer + Extension.swift
//  HazardReporter
//
//  Created by Lam Nguyen Huu (VN) on 27/12/2021.
//  Copyright © 2021 pluralsight. All rights reserved.
//

import Foundation
import CloudKit
import UIKit

extension CKContainer {
    func fetchCloudKitRecordChanges(completion: @escaping ([RecordChange]) -> () ) {
        let existingChangeToken = UserDefaults().serverChangeToken
        let notificationChangesOperation = CKFetchNotificationChangesOperation(previousServerChangeToken: existingChangeToken)
        // Cache change reason
        var changeReasons = [CKRecordID: CKQueryNotificationReason]()
        notificationChangesOperation.notificationChangedBlock = {
            notification in
            if let n = notification as? CKQueryNotification, let recordID = n.recordID {
                changeReasons[recordID] = n.queryNotificationReason
            }
        }
        
        notificationChangesOperation.fetchNotificationChangesCompletionBlock = {
            newChangeToken, error in
            guard  error == nil else {return}
            guard changeReasons.count > 0 else {return}
            
            UserDefaults().serverChangeToken = newChangeToken
            var deletedIDs = [CKRecordID]()
            var insertedOrUpdatedIDs = [CKRecordID]()
            
            for (recordID, reason) in changeReasons {
                switch reason {
                case .recordDeleted:
                    deletedIDs.append(recordID)
                default:
                    insertedOrUpdatedIDs.append(recordID)
                }
            }
            // Fetch inserted/updated CKRecord instances based upon their Records ID
            
            let fetchRecordsOperation = CKFetchRecordsOperation(recordIDs: insertedOrUpdatedIDs)
            
            fetchRecordsOperation.fetchRecordsCompletionBlock = { records, error in
                var changes: [RecordChange] = deletedIDs.map({RecordChange.deleted($0)})
                for (id, record) in records ?? [:] {
                    guard let reason = changeReasons[id] else {continue}
                    switch reason {
                    case .recordCreated:
                        changes.append(RecordChange.created(record))
                    case .recordUpdated:
                        changes.append(RecordChange.udpated(record))
                    default:
                        fatalError("Inserts and updates only in this block...")
                    }
                }
                completion(changes)
            }
            self.publicCloudDatabase.add(fetchRecordsOperation)
        }
        
        self.add(notificationChangesOperation)
    }
}

public extension UserDefaults {
    var serverChangeToken: CKServerChangeToken? {
        get {
            guard let data = self.value(forKey: "ChangeToken") as? Data  else {
                return nil
            }
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {return nil}
            return token
        }
        set {
            if let token = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "ChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "ChangeToken")
            }
        }
    }
}
