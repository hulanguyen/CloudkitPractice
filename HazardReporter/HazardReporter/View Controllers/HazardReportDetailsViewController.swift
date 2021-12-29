import UIKit
import MapKit
import CloudKit

class HazardReportDetailsViewController: UIViewController {
	@IBOutlet weak var emergencyIndicatorLabel: UILabel!
	@IBOutlet weak var hazardDescriptionLabel: UILabel!
	@IBOutlet weak var hazardImageView: UIImageView!
	@IBOutlet weak var hazardLocationMapView: MKMapView!
    var hazardReport: HazardReport!
    
    
	override func viewDidLoad() {
		super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleLocalRecordChange), name: recordDidChangedLocally, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteRecordChange), name: recordDidChangedRemotelly, object: nil)

        refreshView()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: recordDidChangedLocally, object: nil)
        NotificationCenter.default.removeObserver(self, name: recordDidChangedRemotelly, object: nil)
    }
    
    @objc func handleRemoteRecordChange(_ notification: Notification) {
        CKContainer.default().fetchCloudKitRecordChanges { changes in
            self.processRecordChanges(changes)
        }
    }
    
    func processRecordChanges(_ recordChanges: [RecordChange]) {
        for recordChange in recordChanges {
            switch recordChange {
            case .udpated(let updatedCKRecord):
                guard updatedCKRecord.recordID.recordName == hazardReport.cloudKitReport.recordID.recordName else {return}
                hazardReport = HazardReport(record: updatedCKRecord)
            default:
                break
            }
        }
        DispatchQueue.main.async {
            self.refreshView()
        }
    }
    
    @objc func handleLocalRecordChange(_ notification: Notification) {
        guard let recordChange = notification.userInfo?["recordChange"] as? RecordChange else {return}
        processRecordChanges([recordChange])
        
    }
    
    func refreshView() {
        emergencyIndicatorLabel.isHidden = !hazardReport.isEmergency
        hazardDescriptionLabel.text = hazardReport.hazardDescription
        
        let location = hazardReport.hazardLocation ?? CLLocation(latitude: 34.111, longitude: -97.111)
        let hazardRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000, 1000)
        hazardLocationMapView.setRegion(hazardRegion, animated: true)
        
        let annotation = MKPointAnnotation()
        annotation.title = "Hazard!"
        annotation.coordinate = location.coordinate
        
        hazardLocationMapView.addAnnotation(annotation)
    }
    
    // MARK: - Delete Hazard Report
	@IBAction func deleteButtonTapped(_ sender: UIBarButtonItem) {
		let alertController = UIAlertController(title: "Delete Hazard Report",
												message: "Are you sure you want to delete this hazard report?",
												preferredStyle: .actionSheet)
		
		let deleteAction = UIAlertAction(title: "Delete", style: .destructive) {
			(_) -> Void in
			
            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [self.hazardReport.cloudKitReport.recordID])
            deleteOperation.modifyRecordsCompletionBlock = { records, ids, error in
                guard let id = ids?[0] else {return}
                NotificationCenter.default.post(name: recordDidChangedLocally, object: self, userInfo: ["recordChange": RecordChange.deleted(id)])
            }
            CKContainer.default().publicCloudDatabase.add(deleteOperation)
			let _ = self.navigationController?.popViewController(animated: true)
		}
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		
		alertController.addAction(deleteAction)
		alertController.addAction(cancelAction)
		
		self.present(alertController, animated: true, completion: nil)
	}
	
    // MARK: - Resolve Hazard Report
	@IBAction func resolveButtonTapped(_ sender: UIBarButtonItem) {
        hazardReport.isResoved = true
        
        let ac = UIAlertController(title: "Resolved Hazard", message: nil, preferredStyle: .alert)
        ac.addTextField { textField in
            textField.placeholder = "Name"
        }
        ac.addTextField { textField in
            textField.placeholder = "Resolution Description"
        }
        ac.addAction(UIAlertAction(title: "Resolve", style: .default, handler: { _ in
            if let text1 = ac.textFields?[0], let text2 = ac.textFields?[1] {
                let referenceToHazardReport = CKReference(record: self.hazardReport.cloudKitReport, action: .deleteSelf)
                
                let hazardResolutionRecord = HazardResolution(resolutionDescription: text1.text ?? "", safetyStaffMemberName: text2.text ?? "", owningHazardReport: referenceToHazardReport)
                
                let resolvedModification = CKModifyRecordsOperation(recordsToSave: [self.hazardReport.cloudKitReport, hazardResolutionRecord.cloudKitRecord], recordIDsToDelete: nil)
                resolvedModification.modifyRecordsCompletionBlock = { saveRecords, deletedRecordIds, error in
                    guard let updatedRecord = saveRecords?[0] else {return}
                    NotificationCenter.default.post(name: recordDidChangedLocally, object: self, userInfo: ["recordChange": RecordChange.udpated(updatedRecord)])
                    
                }
                CKContainer.default().publicCloudDatabase.add(resolvedModification)
                let _ = self.navigationController?.popViewController(animated: true)
            }
        }))
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
        
		
	}
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "editHazardReport":
            let navigationController = segue.destination as! UINavigationController
            let editVc = navigationController.viewControllers[0] as! EditHazardReportViewController
            editVc.hazardReportToEdit = hazardReport
        default: break
        }
    }
}
