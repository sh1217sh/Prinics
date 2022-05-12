//
//  PrinterConnectionManager.swift
//  Prinics
//
//  Created by Sungho Lee on 5/6/22.
//

import Foundation
import NetworkExtension

class PrinterConnectionManager {
    
//    static let shared = PrinterConnectionManager()
    private lazy var hotspotConfigManager = {
        return NEHotspotConfigurationManager.shared
    }()
    private let ssidPrefix = "DIRECT-Kodak-"
    private let password = "12345678"
    
//    private init() { }
    
    func joinPrinterNetwork() async throws {
        let config = NEHotspotConfiguration(ssidPrefix: ssidPrefix, passphrase: password, isWEP: false)
        config.joinOnce = true
        try await hotspotConfigManager.apply(config)
    }
    
//    func disconnectFromPrinterNetwork() async {
//        let ssids = await hotspotConfigManager.configuredSSIDs()
//        print(ssids)
//        ssids.forEach(hotspotConfigManager.removeConfiguration(forSSID:))
//    }
    
}
