//
//  HazardReport.swift
//  HazardReporter
//
//  Created by Lam Nguyen Huu (VN) on 25/12/2021.
//  Copyright © 2021 pluralsight. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

public struct HazardReport {
    public var hazardDescription: String
    public var hazardLocation: CLLocation?
    public var hazardPhoto: UIImage?
    public var isEmergency: Bool
    public var isResoved: Bool
    
    // Creation in iCloud
    public var creationDate: Date?
    public var modificationDate: Date?
    public var encodeSystemFields: Data?
    
    init(hazardDescription: String,
         hazardLocation: CLLocation?,
         hazardPhoto: UIImage?,
         isEmergency: Bool,
         isResolved: Bool
    ) {
        self.hazardDescription = hazardDescription
        self.hazardLocation = hazardLocation
        self.hazardPhoto = hazardPhoto
        self.isEmergency = isEmergency
        self.isResoved = isResolved
    }
    
    init(record: CKRecord) {
        
        let data = NSMutableData()
        let coder = NSKeyedArchiver(forWritingWith: data)
        coder.requiresSecureCoding = true
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        
        self.encodeSystemFields = data as Data
        
        
        self.hazardDescription = record["hazardDescription"] as! String
        self.hazardLocation = record["hazardLocation"] as? CLLocation
        
        // Asset --> File URL
        // File URL --> Data instance
        // Data instance --> UIImage
        
        if let photoAsset = record["hazardPhoto"] as? CKAsset,
           let photoData = try? Data(contentsOf: photoAsset.fileURL) {
            self.hazardPhoto = UIImage(data: photoData)
        }
        
        self.isEmergency = record["isEmergency"] as! Bool
        self.isResoved = record["isResolved"] as! Bool
        self.creationDate = record.creationDate
        self.modificationDate = record.modificationDate
    }
    
    public var cloudKitReport: CKRecord {
        
        var hazardReport: CKRecord
        if let systemFields = self.encodeSystemFields {
            let decoder = NSKeyedUnarchiver(forReadingWith: systemFields)
            decoder.requiresSecureCoding = true
            hazardReport = CKRecord(coder: decoder)!
            decoder.finishDecoding()
        } else {
            hazardReport = CKRecord(recordType: "HazardReport")
        }
        
        
        hazardReport["hazardDescription"] = hazardDescription as NSString
        if let location = hazardLocation {
            hazardReport["hazardLocation"] = location
        }
        hazardReport["isEmergency"] = NSNumber(booleanLiteral: isEmergency)
        hazardReport["isResolved"] = NSNumber(booleanLiteral: isResoved)
        
        if let image = hazardPhoto {
            let hazardPhotoFileName = ProcessInfo.processInfo.globallyUniqueString + ".jpg"
            let hazardPhotoFileURL = URL.init(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(hazardPhotoFileName)
            
            let hazardPhotoData = UIImageJPEGRepresentation(image, 0.7)
            
            do {
                try hazardPhotoData?.write(to: hazardPhotoFileURL)
            } catch {
                debugPrint("Cannot write imag to url: \(hazardPhotoFileURL.absoluteString)")
            }
            hazardReport["hazardPhoto"] = CKAsset(fileURL: hazardPhotoFileURL)
        }
        
        return hazardReport
    }
}
