//
//  ChangeNotification.swift
//  HazardReporter
//
//  Created by Lam Nguyen Huu (VN) on 27/12/2021.
//  Copyright © 2021 pluralsight. All rights reserved.
//

import Foundation
import CloudKit

let recordDidChangedLocally = Notification.Name("com.hula.hazardReport.localChangeKey")
let recordDidChangedRemotelly = Notification.Name("com.hula.hazardReport.remoteChangeKey")

enum RecordChange {
    case created(CKRecord)
    case udpated(CKRecord)
    case deleted(CKRecordID)
}
