//
//  PrintViewController.swift
//  Prinics
//
//  Created by Sungho Lee on 5/11/22.
//

import UIKit

class PrintViewController: UIViewController, PrintManagerDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    var image: UIImage?
    private let printManager = PrintManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        isModalInPresentation = true
        
        guard let image = image else {
            dismiss(animated: true)
            return
        }
        
        printManager.delegate = self
        
        activityIndicator.startAnimating()
        progressBar.isHidden = true
        closeButton.isHidden = true
        
        Task {
            await printManager.printImage(image)
        }
    }
    
    @IBAction func close() {
        dismiss(animated: true)
    }
    
    func printProgressUpdated(progress: PrintProgress) {
        DispatchQueue.main.async {
            self.imageView.image = UIImage(systemName: "printer")
            self.imageView.tintColor = .systemBlue
            
            self.activityIndicator.stopAnimating()
            self.progressBar.isHidden = false
            
            let progressMessage: String
            switch progress {
            case .sendingImage:
                progressMessage = "Sending photo to printer"
                self.progressBar.progress = 0.0
            case .printing(let step):
                switch step {
                case .yellow:
                    progressMessage = "Printing yellow"
                    self.progressBar.progress = 0.2
                case .magenta:
                    progressMessage = "Printing magenta"
                    self.progressBar.progress = 0.4
                case .cyan:
                    progressMessage = "Printing cyan"
                    self.progressBar.progress = 0.6
                case .lamination:
                    progressMessage = "Laminating"
                    self.progressBar.progress = 0.8
                }
            }
            self.label.text = progressMessage
        }
    }
    
    func printSucceed() {
        DispatchQueue.main.async {
            self.imageView.image = UIImage(systemName: "checkmark.circle")
            self.imageView.tintColor = .systemGreen
            
            self.activityIndicator.stopAnimating()
            self.progressBar.isHidden = true
            self.label.text = "Finished printing"
            self.closeButton.isHidden = false
        }
    }
    
    func printFailed(error: PrintError) {
        print(error)
        DispatchQueue.main.async {
            self.imageView.image = UIImage(systemName: "x.circle")
            self.imageView.tintColor = .systemRed
            
            self.activityIndicator.stopAnimating()
            self.progressBar.isHidden = true
            
            var errorMessage = "Unknown error"
            switch error {
            case .printerError(let status):
                switch status {
                case .lowBattery:
                    errorMessage = "Low battery.\nPlease charge the printer."
                default:
                    break
                }
            case .socketError(_):
                errorMessage = "Lost connection to the printer"
            case .connectionError(_):
                errorMessage = "Cannot connect to the printer"
            case .noImage:
                break
            }
            self.label.text = errorMessage
            self.closeButton.isHidden = false
        }
    }
    
    func printWarning(_ warning: PrintWarning) {
        DispatchQueue.main.async {
            self.imageView.image = UIImage(systemName: "exclamationmark.triangle")
            self.imageView.tintColor = .systemYellow
            
            self.activityIndicator.stopAnimating()
            self.progressBar.isHidden = true
            switch warning {
            case .cartridge:
                self.label.text = "Out of paper or cartridge not installed.\nPlease replace the cartridge. Printer will automatically resume after new cartridge is installed."
            }
        }
    }

}
