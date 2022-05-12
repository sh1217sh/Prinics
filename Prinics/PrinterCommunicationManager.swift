//
//  PrinterCommunicationManager.swift
//  
//
//  Created by Sungho Lee on 5/7/22.
//

import Foundation
import Socket

// Message structure
// It is completely based on my guess after performing a network capture.
// +----+----+---+---+----+----+---+---+------------+
// |  0 |  1 | 2 | 3 |  4 |  5 | 6 | 7 |     ...    |
// +----+----+---+---+----+----+---+---+------------+
// | Command |  Data | Extra data size | Extra data |
// +---------+-------+-----------------+------------+

enum PrinterMessage {
    enum PrintingSteps: UInt8 {
        case yellow
        case magenta
        case cyan
        case lamination
    }
    enum PrinterStatus {
        case normal
        case lowBattery
        case noCartridge
        
        init? (data: Data) {
            switch data {
            case Data([0x00, 0x00]):
                self = .normal
            case Data([0x29, 0x00]):
                self = .lowBattery
            case Data([0x14, 0x01]):
                self = .noCartridge
            default:
                return nil
            }
        }
    }
    
    case handshake
    case statusReport(status: PrinterStatus?)
    case readyForImage
    case imageChunkRequest(chunkNumber: UInt8, location: UInt32, size: UInt32)
    case printProgressReport(pageNumber: UInt8, step: PrintingSteps)
    case printError(status: PrinterStatus?)
    case printDone
    
    // Not sure what these commands mean
    case x3219
    case x321B
    case x321E
    case x3221
    case x3222
    
    init? (data: Data) {
        let prefix = data[0 ..< 2]
        switch prefix {
        case Data([0x02, 0x09]):
            self = .handshake
        case Data([0x04, 0x01]):
            let status = PrinterStatus(data: data[2 ..< 4])
            self = .statusReport(status: status)
        case Data([0x01, 0x05]):
            self = .readyForImage
        case Data([0x04, 0x02]):
            self = .readyForImage
        case Data([0x08, 0x00]):
            let chunkNumber = data[2]
            let location = data[8 ..< 12].uInt32Value
            let size = data[12 ..< 16].uInt32Value
            self = .imageChunkRequest(chunkNumber: chunkNumber, location: location, size: size)
        case Data([0x04, 0x03]):
            guard let step = PrintingSteps(rawValue: data[15]) else { return nil }
            self = .printProgressReport(pageNumber: data[1], step: step)
        case Data([0x04, 0x04]):
            let status = PrinterStatus(data: data[2 ..< 4])
            self = .printError(status: status)
        case Data([0x04, 0x06]):
            self = .printDone
            
        case Data([0x32, 0x19]): self = .x3219
        case Data([0x32, 0x1B]): self = .x321B
        case Data([0x32, 0x1E]): self = .x321E
        case Data([0x32, 0x21]): self = .x3221
        case Data([0x32, 0x22]): self = .x3222
            
        default:
            return nil
        }
    }
}

enum AppMessage {
    case handshake
    case metadataResponse(numberOfCopies: UInt8, imageDataSize: UInt32)
    case readyToSendImage
    case imageChunkResponse(chunkNumber: UInt8, imageDataChunk: Data)
    
    var data: Data {
        switch self {
        case .handshake:
            return Data([0x02, 0x09, 0x52, 0x00, 0x00, 0x00, 0x00, 0x00])
        case .metadataResponse(let numberOfCopies, let imageDataSize):
            // This one doesn't follow the message structure for some reason.
            let bytes: [UInt8] = [0x05, numberOfCopies, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04] + imageDataSize.bytes
            return Data(bytes)
        case .readyToSendImage:
            return Data([0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        case .imageChunkResponse(let chunkNumber, let imageDataChunk):
            let commandBytes = [0x09, 0x00, chunkNumber, 0x00] + UInt32(imageDataChunk.count).bytes
            var data = Data(commandBytes)
            data.append(imageDataChunk)
            return data
        }
    }
}

class PrinterCommunicationManager {
    
    weak var delegate: PrinterCommunicationManagerDelegate?
    private var printerSocket: Socket?
    
    func connect() throws {
        let printerSocket = try Socket.create()
        self.printerSocket = printerSocket
        // It would be better to "discover" the IP using UDP broadcast but it requires Apple's permission.
        // So it's hardcoded for now.
        try printerSocket.connect(to: "192.168.42.1", port: 56067, timeout: 10000)
        
        DispatchQueue.global(qos: .userInitiated).async {
            while printerSocket.isConnected {
                var data = Data()
                do {
                    try printerSocket.read(into: &data)
                } catch {
                    self.delegate?.printerCommunicationManagerLostConnection(error: error)
                }
                print(data.hexEncodedString())
                guard let printerMessage = PrinterMessage(data: data) else {
                    self.reportUnknownCode(data)
                    continue
                }
                
                self.delegate?.printerCommunicationManager(self, didRecieve: printerMessage)
            }
        }
    }
    
    func send(message: AppMessage) throws {
        let data = message.data
        try printerSocket?.write(from: data)
    }
    
    func disconnect() {
        printerSocket?.close()
        print("Socket closed")
    }

    func reportUnknownCode(_ code: Data) {
        print("Unknown command: " + code.hexEncodedString(options: [.upperCase]))
    }
    
    // Turns out UDP broadcasting and listening for boradcast require Apple's permission.
    // Won't be able to read printer status but it won't affect the ability to print.
//    func ping() throws {
//        let outSocket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
//        let outAddress = Socket.createAddress(for: "192.168.42.255", on: 56066)!
//
//        let inSocket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
//
//        try outSocket.write(from: "?PPVP", to: outAddress)
//
//        var reply = Data()
//        let (size, printerAddress) = try inSocket.readDatagram(into: &reply)
//        print(size)
//        print(printerAddress)
//
//        outSocket.close()
//        inSocket.close()
//    }
    
}

protocol PrinterCommunicationManagerDelegate: AnyObject {
    
    func printerCommunicationManager(_ manager: PrinterCommunicationManager, didRecieve message: PrinterMessage)
    func printerCommunicationManagerLostConnection(error: Error)
    
}

fileprivate extension Data {
    var uInt32Value: UInt32 {
        return self.map(UInt32.init).enumerated().reduce(0, { $0 + ($1.1 << (24 - ($1.0 * 8))) })
    }
    
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX " : "%02hhx "
        return self.map { String(format: format, $0) }.joined()
    }
}

fileprivate extension UInt32 {
    var bytes: [UInt8] {
        return [UInt8((self >> (8 * 3)) & 0xFF),
                UInt8((self >> (8 * 2)) & 0xFF),
                UInt8((self >> (8 * 1)) & 0xFF),
                UInt8(self & 0xFF)]
    }
}
