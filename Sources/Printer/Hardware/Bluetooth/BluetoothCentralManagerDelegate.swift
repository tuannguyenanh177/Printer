//
//  Delegate.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothCentralManagerDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  struct UserDefaultKey {

    static let autoConectUUID = "auto.connect.uuid"
    static let autoConectMultiUUID = "auto.connect.multi.uuid"
  }

  private var services: Set<String>!

  var peripheralDelegate: [BluetoothPeripheralDelegate] = []

  open var centralManagerDidUpdateState: ((CBCentralManager) -> ())?
  open var centralManagerDidDiscoverPeripheralWithAdvertisementDataAndRSSI: ((CBCentralManager, CBPeripheral, [String : Any], NSNumber) -> ())?
  open var centralManagerDidConnectPeripheral: ((CBCentralManager, CBPeripheral) -> ())?
  open var centralManagerDidFailToConnectPeripheralWithError: ((CBCentralManager, CBPeripheral, Error?) -> ())?
  open var centralManagerDidDisConnectPeripheralWithError: ((CBCentralManager, CBPeripheral, Error?) -> ())?

  typealias PeripheralChangeBlock = (UUID) -> ()

  var addedPeripherals: PeripheralChangeBlock?
  var updatedPeripherals: PeripheralChangeBlock?
  var removedPeripherals: PeripheralChangeBlock?
  var wellDoneCanWriteData: ((CBPeripheral) -> ())?
  private let writablecharacteristicUUID = "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"

  private(set) var discoveredPeripherals: [UUID: CBPeripheral] = [:]
  private let lock = NSLock()

  subscript(uuid: UUID) -> CBPeripheral? {
    get {
      lock.lock(); defer { lock.unlock() }
      return discoveredPeripherals[uuid]
    }
    set {

      let oldValue = discoveredPeripherals[uuid]?.identifier

      lock.lock()
      discoveredPeripherals[uuid] = newValue
      lock.unlock()

      if newValue == nil {
        if oldValue != nil {
          removedPeripherals?(uuid)
        }
      } else {
        if oldValue == nil {
          addedPeripherals?(uuid)
        } else {
          updatedPeripherals?(uuid)
        }
      }
    }
  }

  convenience init(_ services: Set<String>) {
    self.init()
    self.services = services
  }

  public func centralManagerDidUpdateState(_ central: CBCentralManager) {

    centralManagerDidUpdateState?(central)

    let ss = services.map { CBUUID(string: $0) }

    // discover services for connected per.
    central.retrieveConnectedPeripherals(withServices: ss).forEach { peripheral in
      connectPeripherals(peripheral: peripheral)
    }
  }

  func connectPeripherals(peripheral: CBPeripheral) {
    let ss = services.map { CBUUID(string: $0) }
    if let index = peripheralDelegate.firstIndex(where: { ble in
      ble.writablePeripheral?.identifier == peripheral.identifier
    }) {
      peripheralDelegate[index].wellDoneCanWriteData = { p in
        self.wellDoneCanWriteData?(p)
      }
      peripheral.delegate = self
      peripheral.discoverServices(ss)
    } else {
      let p = BluetoothPeripheralDelegate(BluetoothPrinterManager.specifiedServices, characteristics: BluetoothPrinterManager.specifiedCharacteristics)
      p.wellDoneCanWriteData = { p in
        self.wellDoneCanWriteData?(p)
      }
      p.writablePeripheral = peripheral
      peripheralDelegate.append(p)
      peripheral.delegate = self
      peripheral.discoverServices(ss)
    }
  }

  public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    guard let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
          let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
          serviceUUIDs.count > 0, isConnectable == 1 else {
      return
    }

    // if peripheral doesn't container specified services, ignore.
    let peripheralServiceSet = Set(serviceUUIDs.map { $0.uuidString } )

    guard peripheralServiceSet.intersection(services).count > 0 else {

      return
    }

    self[peripheral.identifier] = peripheral

    if let uuids = UserDefaults.standard.object(forKey: UserDefaultKey.autoConectMultiUUID) as? [String] {
      uuids.forEach { uuid in
        if peripheral.identifier.uuidString == uuid {
          central.connect(peripheral, options: nil)
        }
      }
    }
    centralManagerDidDiscoverPeripheralWithAdvertisementDataAndRSSI?(central, peripheral, advertisementData, RSSI)
  }

  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    centralManagerDidConnectPeripheral?(central, peripheral)
    connectPeripherals(peripheral: peripheral)
  }

  public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    centralManagerDidFailToConnectPeripheralWithError?(central, peripheral, error)
  }

  public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    centralManagerDidDisConnectPeripheralWithError?(central, peripheral, error)
  }

  public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

      guard error == nil else { return }

      guard let prServices = peripheral.services else {
          return
      }

      prServices.filter { services.contains($0.uuid.uuidString) }.forEach {
          peripheral.discoverCharacteristics(nil, for: $0)
      }
  }

  public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let index = peripheralDelegate.firstIndex(where: { ble in
      ble.writablePeripheral?.identifier == peripheral.identifier
    }) {
      peripheralDelegate[index].writablePeripheral = peripheral
      peripheralDelegate[index].writablecharacteristic = service.characteristics?.filter { $0.uuid.uuidString == writablecharacteristicUUID }.first
    }
  }

  public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      print(characteristic)
  }
}
