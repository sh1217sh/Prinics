//
//  PrinterStatusViewController.swift
//  Prinics
//
//  Created by Sungho Lee on 4/2/22.
//

//import UIKit
//
//class PrinterStatusViewController: UIViewController {
//
//    @IBOutlet weak var macLabel: UILabel!
//
//    private lazy var connectionManager = {
//        return PrinterConnectionManager.shared
//    }()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//    }
//
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        Task {
//            do {
//                try await connectionManager.joinPrinterNetwork()
//                print("Connected")
//                let communicationManager = PrinterCommunicationManager.shared
//                try communicationManager.ping()
//            } catch {
//                print(error.localizedDescription)
//            }
//        }
//    }
//
//    override func viewDidDisappear(_ animated: Bool) {
//        Task {
//            await connectionManager.disconnectFromPrinterNetwork()
//        }
//        super.viewDidDisappear(animated)
//    }
//
//}
