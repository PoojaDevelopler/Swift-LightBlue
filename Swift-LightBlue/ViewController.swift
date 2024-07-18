//
//  ViewController.swift
//  Swift-LightBlue
//
//  Created by pnkbksh on 10/07/24.
//

import UIKit
import CoreBluetooth

struct CBUUIDs {
    
    static  let heartRateServiceCBUUID = CBUUID(string: "0x180D")
    static let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "0x2A37")
    static let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "0x2A38")
    
}



class ViewController: UIViewController {
    
    @IBOutlet weak var deviceName:UILabel!
    @IBOutlet weak var heartRateLbl:UILabel!
    @IBOutlet weak var bodySensorLocationLbl:UILabel!
    
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make the digits monospaces to avoid shifting when the numbers change
        deviceName.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLbl.font!.pointSize, weight: .bold)
        heartRateLbl.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLbl.font!.pointSize, weight: .regular)
        
        // MARK: - 1) Initialize Central Manager, it represents the iOS device
        // This will call centralManagerDidUpdateState delegate method
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])

    }
    
    func onHeartRateReceived(_ heartRate: Int) {
        self.heartRateLbl.text = String(heartRate)
        print("BPM: \(heartRate)")
    }
    
}


extension ViewController: CBCentralManagerDelegate {
//    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
            
        case .poweredOn:
            print("central.state is .poweredOn")
            // MARK: - 2) Start scanning for Peripherals
            // Here we specifically looking for peripherals with Heart Rate service
            // We can change the UUID to look for peripherals with other services
            // Or we can set it to nil and get all peripherals around
           
            // This will call didDiscover delegate method
            centralManager.scanForPeripherals(withServices: nil, options: nil)

            
        @unknown default:
            print("something went wrong")
        }
    }
    
    // MARK: - 3) Here we get a reference to the peripheral
    // Now we stop scanning other for other peripherals
    // And connect to heartRatePeripheral
    // This will call didConnect delegate method
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        guard let deviceName = advertisementData["kCBAdvDataLocalName"] as? String , deviceName == "Heart Rate" else {
            return
        }
        
        //MARK: - METHOD_2 FOR FILTERING THE PERIPHERALS
            print ("Advertisement Data : \(advertisementData)")
            
            heartRatePeripheral = peripheral
            heartRatePeripheral.delegate = self
            print("Peripheral Discovered: \(peripheral)")
            print("Peripheral name: \(peripheral.name ?? "")")
            
            
            self.centralManager.stopScan()
            self.centralManager.connect(peripheral, options: nil)
            self.heartRatePeripheral = peripheral
            
            self.deviceName.text = "Device Name : \(deviceName)"
            print("EXPECTED_PERIPHERALS = \(self.heartRatePeripheral!)")
        
        
        
    }
    
    // MARK: - 4) Here the iOS device as a central and the Hart Rate sensor as a peripheral are connected
    // Now we dicover the Heart Rate Service in the Peripheral
    // We can discover all available services by setting the array to nil
    // This will call didDiscoverServices delegate method
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        heartRatePeripheral.discoverServices([CBUUIDs.heartRateServiceCBUUID])
    }
}

extension ViewController: CBPeripheralDelegate {
    
    // MARK: - 5) Here we get an array that has one element which is Hate Rate service
    // Now we discover all characteristics in the Hate Rate service
    // This will call didDiscoverCharacteristicsFor delegate method
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print(service)
            print(service.characteristics ?? "characteristics are nil")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    
    // MARK: - 6) Here we get 2 Characteristics:
    // 1. Body Location Characteristic: has read property for one time read
    // 2. Heart Rate Measurement Characteristic: has notify property, to notify the iOS device every time the hart rate changes
    // This will update didUpdateValueFor delegate method
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
//            print(characteristic)
            
            // Body Location Characteristic
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read" , characteristic)
                peripheral.readValue(for: characteristic)
            }
            
            // Heart Rate Measurement Characteristic
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify" , characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
        }
    }
    
    
    // MARK: - 7) Here we get the value of the Body Location one time & the value of Heart Rate every notification
    // So we read the characteristic value and show it on the corresponding Label
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        print("characteristic found: \(characteristic)")
        switch characteristic.uuid {
        case CBUUIDs.bodySensorLocationCharacteristicCBUUID:
            let bodySensorLocation = bodyLocation(from: characteristic)
            self.bodySensorLocationLbl.text = bodySensorLocation
        case CBUUIDs.heartRateMeasurementCharacteristicCBUUID:
            let bpm = heartRate(from: characteristic)
            onHeartRateReceived(bpm)
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
}


// MARK: - Helper Functions
extension ViewController {
    private func bodyLocation(from characteristic: CBCharacteristic) -> String {
        guard let characteristicData = characteristic.value,
              let byte = characteristicData.first else { return "Error" }
        
        switch byte {
        case 0: return "Other"
        case 1: return "Chest"
        case 2: return "Wrist"
        case 3: return "Finger"
        case 4: return "Hand"
        case 5: return "Ear Lobe"
        case 6: return "Foot"
        default:
            return "Reserved for future use"
        }
    }
    
    private func heartRate(from characteristic: CBCharacteristic) -> Int {
        print("m checking ")
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart Rate Value Format is in the 2nd byte
            return Int(byteArray[1])
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
        }
    }
}
