import UIKit
import CloudKit

class ActiveHazardReportsViewController:    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate
{
    
    @IBOutlet weak var tableView: UITableView!
    var hazardReports = [HazardReport]()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleLocalRecordChange),
                                               name: recordDidChangedLocally,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRemoteRecordChange),
                                               name: recordDidChangedRemotelly,
                                               object: nil)
        
        let predicate = NSPredicate(format: "isResolved == 0")
        let activeHazardsQuery = CKQuery(recordType: "HazardReport", predicate: predicate)
        let creationDateSortDescriptor = NSSortDescriptor(key: "creationDate", ascending: true)
        activeHazardsQuery.sortDescriptors = [creationDateSortDescriptor]
        
        CKContainer.default().publicCloudDatabase.perform(activeHazardsQuery, inZoneWith: nil) { records, error in
            print(error.debugDescription)
            guard let records = records else {return}
            print(records)
            self.hazardReports = records.map({HazardReport(record: $0)})
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: recordDidChangedLocally, object: nil)
    }
    
    @objc func handleRemoteRecordChange(_ notification: Notification) {
        CKContainer.default().fetchCloudKitRecordChanges { changes in
            self.processChanges(changes)
        }
    }
    
    func processChanges(_ recordChanges: [RecordChange]) {
        for recordChange in recordChanges {
            switch recordChange {
            case .created(let createdCKRecord):
                let newHazardReport = HazardReport(record: createdCKRecord)
                guard newHazardReport.isResoved == false else {break}
                hazardReports.append(newHazardReport)
            case .udpated(let updatedCKRecord):
                let existingIndex = hazardReports.firstIndex(where: {$0.cloudKitReport.recordID.recordName == updatedCKRecord.recordID.recordName})
                if let index = existingIndex {
                    let updatedHazardReport = HazardReport(record: updatedCKRecord)
                    if updatedHazardReport.isResoved {
                        hazardReports.remove(at: index)
                    } else {
                        hazardReports[index] = updatedHazardReport
                    }
                }
            case .deleted(let deletedCkRecordId):
                let existingIndex = hazardReports.firstIndex(where: {$0.cloudKitReport.recordID.recordName == deletedCkRecordId.recordName})
                if let index = existingIndex {
                    hazardReports.remove(at: index)
                }
            }
        }
        
        hazardReports.sort { firstReport, secondReport in
            firstReport.creationDate! < secondReport.creationDate!
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc func handleLocalRecordChange(_ notification: Notification) {
        guard let recordChange = notification.userInfo?["recordChange"] as? RecordChange else {return}
        self.processChanges([recordChange])
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
        return hazardReports.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hazardReportCell",
                                                 for: indexPath)
        
        let dispHazardReport = hazardReports[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        if let createDate = dispHazardReport.creationDate {
            cell.textLabel?.text = dateFormatter.string(from: createDate)
        }
        cell.detailTextLabel?.text = dispHazardReport.hazardDescription
        if dispHazardReport.isEmergency {
            cell.imageView?.image = UIImage(named: "emergency-hazard-icon")
        } else {
            cell.imageView?.image = UIImage(named: "hazard-icon")
        }
        return cell
    }
    
    // MARK: TableView Delegate methods
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier! {
        case "hazardReportDetails":
            let destinationVC = segue.destination as! HazardReportDetailsViewController
            
            let selectedIndex = tableView.indexPathForSelectedRow!.row
            let selectedHazardReports = hazardReports[selectedIndex]
            destinationVC.hazardReport = selectedHazardReports
            
        case "addHazardReport":
            let navigationController = segue.destination as! UINavigationController
            let editVC = navigationController.viewControllers[0] as! EditHazardReportViewController
//            editVC.hazardReportToEdit = hazardReports[tableView.indexPathForSelectedRow!.row]
        default: break
        }
    }
}
