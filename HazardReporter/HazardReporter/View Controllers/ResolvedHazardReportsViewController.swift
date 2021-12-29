import UIKit
import CloudKit

class ResolvedHazardReportsViewController:     UIViewController,
    UITableViewDataSource,
    UITableViewDelegate
{
    
    @IBOutlet weak var tableView: UITableView!
    var hazardRecords: [HazardReport] = []
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleLocalRecordChange), name: recordDidChangedLocally, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteRecordChange), name: recordDidChangedRemotelly, object: nil)
        
        let predicate = NSPredicate(format: "isResolved == 1")
        
        let resolvedQuery = CKQuery(recordType: "HazardReport", predicate: predicate)
        let modificationDateSortDescriptor = NSSortDescriptor(key: "modificationDate", ascending: false)
        resolvedQuery.sortDescriptors = [modificationDateSortDescriptor]
        
        CKContainer.default().publicCloudDatabase.perform(resolvedQuery, inZoneWith: nil) { ckrecords, error in
            if let records = ckrecords {
                self.hazardRecords = records.map({HazardReport(record: $0)})
            }
            
            for report in self.hazardRecords {
                let hazardReportReference = CKReference(record: report.cloudKitReport, action: .none)
                let predicate = NSPredicate(format: "owningHazardReport == %@", hazardReportReference)
                let query  = CKQuery(recordType: "HazardResolution", predicate: predicate)
                
                CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { hazardRecorResolutions, error in
                    print(hazardRecorResolutions)
                }
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
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
            case .created(let createdCKRecord):
                let newHazardReport = HazardReport(record: createdCKRecord)
                guard newHazardReport.isResoved == true else {break}
                hazardRecords.append(newHazardReport)
            case .udpated(let updatedCKRecord):
                let existingIndex = hazardRecords.firstIndex(where: {$0.cloudKitReport.recordID.recordName == updatedCKRecord.recordID.recordName})
                if let index = existingIndex {
                    let updatedHazardReport = HazardReport(record: updatedCKRecord)
                    if updatedHazardReport.isResoved {
                        hazardRecords[index] = updatedHazardReport
                    } else {
                        hazardRecords.remove(at: index)
                    }
                } else {
                    let newHazardReport = HazardReport(record: updatedCKRecord)
                    guard newHazardReport.isResoved else {continue}
                    hazardRecords.append(newHazardReport)
                }
            case .deleted(let deletedCkRecordId):
                let existingIndex = hazardRecords.firstIndex(where: {$0.cloudKitReport.recordID.recordName == deletedCkRecordId.recordName})
                if let index = existingIndex {
                    hazardRecords.remove(at: index)
                }
            }
        }
        hazardRecords.sort { firstReport, secondReport in
            firstReport.modificationDate! > secondReport.modificationDate!
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc func handleLocalRecordChange(_ notification: Notification) {
        guard let recordChange = notification.userInfo?["recordChange"] as? RecordChange else {return}
        self.processRecordChanges([recordChange])
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: TableView Data Source methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return hazardRecords.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hazardReportCell",
                                                 for: indexPath)
        let disRecord = hazardRecords[indexPath.row]
        let formettter = DateFormatter()
        formettter.dateFormat = "MMMM dd, yyyy"
        if let createDate = disRecord.creationDate {
            cell.textLabel?.text = formettter.string(from: createDate)
        }
        
        cell.detailTextLabel?.text = disRecord.hazardDescription
        
        return cell
    }
    
    // MARK: TableView Delegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "resolvedHazardDetails":
            let destinationVC = segue.destination as! HazardReportDetailsViewController
            destinationVC.hazardReport = hazardRecords[tableView.indexPathForSelectedRow!.row]
        default: break
        }
    }
    
}
