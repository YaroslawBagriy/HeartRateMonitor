/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreBluetooth

// UUIDs for Services
let heartRateServiceCBUUID = CBUUID(string: "0x180D")

// UUIDs for Characteristics
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")

class HRMViewController: UIViewController {

  @IBOutlet weak var heartRateLabel: UILabel!
  @IBOutlet weak var bodySensorLocationLabel: UILabel!
  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral!
  
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // Make the digits monospaces to avoid shifting when the numbers change
    heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
    
    // Initilize Central Manager
    centralManager = CBCentralManager(delegate: self, queue: nil)
    
  }

  func onHeartRateReceived(_ heartRate: Int) {
    heartRateLabel.text = String(heartRate)
    print("BPM: \(heartRate)")
  }
}


// MARK: Bluetooth

extension HRMViewController: CBCentralManagerDelegate {
  // This gets called right when the View Loads
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
      
    case .unknown:
      <#code#>
    case .resetting:
      <#code#>
    case .unsupported:
      <#code#>
    case .unauthorized:
      <#code#>
    case .poweredOff:
      <#code#>
    case .poweredOn:
      // If Bluetooth is powered on, start scanning for peripherals
      // Only scan for Peripherals with a specific UUID
      print("central.state is .poweredOn")
      centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])
    }
    
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    // Peripheral found
    heartRatePeripheral = peripheral
    // Set Peripherals delegate to seld
    heartRatePeripheral.delegate = self
    // Stop scanning once all peripherals are found
    // This will save energy on both the device and phone
    centralManager.stopScan()
    // Connect the Central Manager to the Peripheral
    centralManager.connect(heartRatePeripheral)
  }
  
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // Once your connected to a peripheral start discovering its Services
    heartRatePeripheral.discoverServices([heartRateServiceCBUUID])
  }
  
}

extension HRMViewController: CBPeripheralDelegate {
  // Essentailly a callback from discoverServices method
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    
    // For each Service of a Peripheral, find it's Characteristics
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                  error: Error?) {
    guard let characteristics = service.characteristics else { return }
    
    // Loop through each Characteristic
    for characteristic in characteristics {
      print(characteristic)
      
      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        // Peripheral will notify the Central Manager when the data is updated
        // This stop polling of data
        peripheral.setNotifyValue(true, for: characteristic)
      }
      
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    switch characteristic.uuid {
    case bodySensorLocationCharacteristicCBUUID:
      let bodySensorLocation = bodyLocation(from: characteristic)
      bodySensorLocationLabel.text = bodySensorLocation
    case heartRateMeasurementCharacteristicCBUUID:
      let bpm = heartRate(from: characteristic)
      onHeartRateReceived(bpm)
    default:
      print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }
  
  // Helper methods to extract data from a services characteristics
  // This can be abstracted further into its own class
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
