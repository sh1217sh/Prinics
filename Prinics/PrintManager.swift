//
//  PrintManager.swift
//  
//
//  Created by Sungho Lee on 5/11/22.
//

import Foundation
import UIKit

class PrintManager: PrinterCommunicationManagerDelegate {
    
    weak var delegate: PrintManagerDelegate?
    
    private let connectionManager = PrinterConnectionManager()
    private let communicationManager = PrinterCommunicationManager()
    private var jpegData: Data?
    
    init() {
        communicationManager.delegate = self
    }

    func printImage(_ image: UIImage) async {
        jpegData = image.jpegData(compressionQuality: 0.7)
        do {
        try await connectionManager.joinPrinterNetwork()
            try self.communicationManager.connect()
        } catch {
            delegate?.printFailed(error: .connectionError(error))
        }
    }
    
    private func send(message: AppMessage) {
        do {
            try communicationManager.send(message: message)
        } catch {
            delegate?.printFailed(error: .socketError(error))
            communicationManager.disconnect()
        }
    }
    
    func printerCommunicationManager(_ manager: PrinterCommunicationManager, didRecieve message: PrinterMessage) {
        switch message {
        case .handshake:
            send(message: .handshake)
            
        case .statusReport(let status):
            guard let jpegData = jpegData else {
                delegate?.printFailed(error: .noImage)
                manager.disconnect()
                return
            }
            switch status {
            case .noCartridge:
                delegate?.printWarning(.cartridge)
            case .lowBattery:
                delegate?.printFailed(error: .printerError(status))
                manager.disconnect()
                return
            default:
                break
            }
            send(message: .metadataResponse(numberOfCopies: 1, imageDataSize: UInt32(jpegData.count)))
            
        case .readyForImage:
            delegate?.printProgressUpdated(progress: .sendingImage)
            send(message: .readyToSendImage)
            
        case .imageChunkRequest(let chunkNumber, let location, let size):
            guard let jpegData = jpegData else {
                delegate?.printFailed(error: .noImage)
                manager.disconnect()
                return
            }
            let start = Int(location)
            let end = Int(location) + Int(size)
            let imageSize = jpegData.count
            var imageChunk = Data()
            if end > imageSize {
                // Append zero padding if the printer requests more data than the actual image size.
                imageChunk = jpegData[start ..< imageSize] + Data(repeating: 0x00, count: end - imageSize)
            } else {
                imageChunk = jpegData[start ..< end]
            }
            send(message: .imageChunkResponse(chunkNumber: chunkNumber, imageDataChunk: imageChunk))
            
        case .printProgressReport(_, let step):
            delegate?.printProgressUpdated(progress: .printing(step))
            
        case .printDone:
            delegate?.printSucceed()
            manager.disconnect()
            
        case .printError(let status):
            switch status {
            case .noCartridge:
                delegate?.printWarning(.cartridge)
            case .lowBattery:
                delegate?.printFailed(error: .printerError(status))
                manager.disconnect()
                return
            default:
                break
            }
            
        default:
            break
        }
    }
    
    func printerCommunicationManagerLostConnection(error: Error) {
        delegate?.printFailed(error: .connectionError(error))
        communicationManager.disconnect()
    }

}

enum PrintProgress {
    case sendingImage
    case printing(PrinterMessage.PrintingSteps)
}

enum PrintError {
    case printerError(PrinterMessage.PrinterStatus?)
    case socketError(Error)
    case connectionError(Error)
    case noImage
}

enum PrintWarning {
    case cartridge
}

protocol PrintManagerDelegate: AnyObject {
    
    func printProgressUpdated(progress: PrintProgress)
    func printSucceed()
    func printFailed(error: PrintError)
    func printWarning(_ warning: PrintWarning)
    
}
