//
//  HazardResolution.swift
//  HazardReporter
//
//  Created by Lam Nguyen Huu (VN) on 28/12/2021.
//  Copyright © 2021 pluralsight. All rights reserved.
//

import Foundation
import CloudKit

struct HazardResolution {
    var resolutionDescription: String
    var safetyStaffMemberName: String
    var owningHazardReport: CKReference
    
    init(resolutionDescription: String, safetyStaffMemberName: String, owningHazardReport: CKReference) {
        self.resolutionDescription = resolutionDescription
        self.safetyStaffMemberName = safetyStaffMemberName
        self.owningHazardReport = owningHazardReport
    }
    
    init(record: CKRecord) {
        self.resolutionDescription = record["resolutionDescription"] as! String
        self.safetyStaffMemberName = record["safetyStaffMemberName"] as! String
        self.owningHazardReport = record["owningHazardReport"] as! CKReference
    }
    
    var cloudKitRecord: CKRecord {
        let record = CKRecord(recordType: "HazardResolution")
        
        record["resolutionDescription"] = resolutionDescription as NSString
        record["safetyStaffMemberName"] = safetyStaffMemberName as NSString
        record["owningHazardReport"] = owningHazardReport
        return record
    }
}
