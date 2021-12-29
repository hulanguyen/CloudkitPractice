import UIKit
import AVFoundation
import CoreLocation
import CloudKit

class EditHazardReportViewController: UIViewController,
    UINavigationControllerDelegate,
    UIImagePickerControllerDelegate,
CLLocationManagerDelegate {
    
    @IBOutlet weak var emergencySegmentedControl: UISegmentedControl!
    @IBOutlet weak var hazardDescriptionTextView: UITextView!
    @IBOutlet weak var hazardImageView: UIImageView!
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation? = nil
    var hazardReportToEdit: HazardReport?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        // Add border to hazard description text view
        hazardDescriptionTextView.layer.borderWidth = CGFloat(0.5)
        hazardDescriptionTextView.layer.borderColor = UIColor(red: 204/255,
                                                              green: 204/255,
                                                              blue: 204/255,
                                                              alpha: 1.0).cgColor
        hazardDescriptionTextView.layer.cornerRadius = 5
        hazardDescriptionTextView.clipsToBounds = true
        setInitUIValues(hazardReportToEdit)
        
        startLocationServices()
    }
    
    func setInitUIValues(_ hazardReport: HazardReport?) {
        guard let report = hazardReport else {return}
        emergencySegmentedControl.selectedSegmentIndex = report.isEmergency ? 1 : 0
        hazardDescriptionTextView.text = report.hazardDescription
        hazardImageView.image = report.hazardPhoto
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Track and Store Current Location
    func startLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        let locationAuthorizationStatus = CLLocationManager.authorizationStatus()
        
        switch locationAuthorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                self.locationManager.startUpdatingLocation()
            }
        case .restricted, .denied: alertLocationAccessNeeded()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: break
        case .authorizedWhenInUse, .authorizedAlways:
            if CLLocationManager.locationServicesEnabled() {
                self.locationManager.startUpdatingLocation()
            }
        case .restricted, .denied: alertLocationAccessNeeded()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        self.currentLocation = locations.last
    }
    
    func alertLocationAccessNeeded() {
        let settingsAppURL = URL(string: UIApplicationOpenSettingsURLString)!
        
        let alert = UIAlertController(
            title: "Need Location Access",
            message: "Location access is required for including the location of the hazard.",
            preferredStyle: UIAlertControllerStyle.alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Allow Location Access",
                                      style: .cancel,
                                      handler: { (alert) -> Void in
                                        UIApplication.shared.open(settingsAppURL,
                                                                  options: [:],
                                                                  completionHandler: nil)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Present Camera and Snap Photo
    @IBAction func snapPictureButtonTapped(_ sender: UIButton) {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthorizationStatus {
        case .notDetermined: requestCameraPermission()
        case .authorized: presentCamera()
        case .restricted, .denied: alertCameraAccessNeeded()
        }
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video,
                                      completionHandler: {accessGranted in
                                        guard accessGranted == true else { return }
                                        self.presentCamera()
        })
    }
    
    func presentCamera() {
        let hazardPhotoPicker = UIImagePickerController()
        hazardPhotoPicker.sourceType = .camera
        hazardPhotoPicker.delegate = self
        
        self.present(hazardPhotoPicker, animated: true, completion: nil)
    }
    
    func alertCameraAccessNeeded() {
        let settingsAppURL = URL(string: UIApplicationOpenSettingsURLString)!
        
        let alert = UIAlertController(
            title: "Need Camera Access",
            message: "Camera access is required for including pictures of hazards.",
            preferredStyle: UIAlertControllerStyle.alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Allow Camera", style: .cancel, handler: { (alert) -> Void in
            UIApplication.shared.open(settingsAppURL,
                                      options: [:],
                                      completionHandler: nil)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        let hazardPhoto = info[UIImagePickerControllerOriginalImage] as! UIImage
        self.hazardImageView.image = hazardPhoto
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Cancelling & Saving
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
        
    }
    
    @IBAction func saveButtonTapped(_ sender: UIBarButtonItem) {

        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        
        if var editedHazardReport = self.hazardReportToEdit {
            editedHazardReport.hazardDescription = hazardDescriptionTextView.text
            editedHazardReport.hazardLocation = currentLocation
            editedHazardReport.hazardPhoto = hazardImageView.image
            editedHazardReport.isEmergency = emergencySegmentedControl.selectedSegmentIndex == 0 ? false : true
            
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [editedHazardReport.cloudKitReport], recordIDsToDelete: nil)
            
            modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                guard let updatedRecords = savedRecords?[0] else {return}
                NotificationCenter.default.post(name: recordDidChangedLocally, object: self, userInfo: ["recordChange": RecordChange.udpated(updatedRecords)])
            }
            
            database.add(modifyOperation)
        } else {
            let hazardReport = HazardReport(hazardDescription: hazardDescriptionTextView.text,
                                            hazardLocation: currentLocation,
                                            hazardPhoto: hazardImageView.image,
                                            isEmergency: emergencySegmentedControl.selectedSegmentIndex == 0,
                                            isResolved: false)
            
            
            database.save(hazardReport.cloudKitReport) { savedRecord, error in
                print(error.debugDescription)
                guard let newRecord = savedRecord else {return}
                NotificationCenter.default.post(name: recordDidChangedLocally, object: self, userInfo: ["recordChange": RecordChange.created(newRecord)])
            }
        }
        
        
        
        self.dismiss(animated: true, completion: nil)
        
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}
