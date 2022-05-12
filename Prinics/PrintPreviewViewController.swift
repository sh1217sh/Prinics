//
//  PrintPreviewViewController.swift
//  Prinics
//
//  Created by Sungho Lee on 5/7/22.
//

import UIKit
import PhotosUI

class PrintPreviewViewController: UIViewController, PHPickerViewControllerDelegate {
    
    @IBOutlet weak var preview: UIView!
    
    private var imageFetchProgress: Progress?
    private var imageView: UIImageView?
    private var lastImageViewTransform: CGAffineTransform = .identity

    override func viewDidLoad() {
        super.viewDidLoad()
    
        showPhotoPicker()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        imageFetchProgress?.cancel()
        
        super.viewDidDisappear(animated)
    }
    
    @IBAction func showPhotoPicker() {
        var pickerConfig = PHPickerConfiguration(photoLibrary: .shared())
        pickerConfig.filter = .images
        
        let picker = PHPickerViewController(configuration: pickerConfig)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func changePhoto(_ image: UIImage) {
        preview.subviews.forEach { $0.removeFromSuperview() }
        
        let imageView = UIImageView(image: image)
        preview.addSubview(imageView)
        
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panView(gestureRecognizer:))))
        imageView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(zoomView(gestureRecognizer:))))
        imageView.addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(rotateView(gestureRecognizer:))))
        
        let scaleFactor: CGFloat
        if imageView.frame.size.width / imageView.frame.size.height >= preview.frame.size.width / preview.frame.size.height {
            scaleFactor = preview.frame.height / imageView.frame.height
        } else {
            scaleFactor = preview.frame.width / imageView.frame.width
        }
        imageView.frame.size = CGSize(width: imageView.frame.width * scaleFactor, height: imageView.frame.height * scaleFactor)
        imageView.center = CGPoint(x: preview.bounds.width / 2, y: preview.bounds.height / 2)
        
        lastImageViewTransform = .identity
    }
    
    @objc func panView(gestureRecognizer: UIPanGestureRecognizer) {
        guard let view = gestureRecognizer.view else { return }
        let translation = gestureRecognizer.translation(in: self.view)
        view.transform = lastImageViewTransform.concatenating(.init(translationX: translation.x, y: translation.y))
        if gestureRecognizer.state == .ended {
            lastImageViewTransform = view.transform
        }
    }
    
    @objc func zoomView(gestureRecognizer: UIPinchGestureRecognizer) {
        guard let view = gestureRecognizer.view else { return }
        let scale = gestureRecognizer.scale
        view.transform = lastImageViewTransform.concatenating(.init(scaleX: scale, y: scale))
        if gestureRecognizer.state == .ended {
            lastImageViewTransform = view.transform
        }
    }
    
    @objc func rotateView(gestureRecognizer: UIRotationGestureRecognizer) {
        guard let view = gestureRecognizer.view else { return }
        let rotation = gestureRecognizer.rotation
        view.transform = lastImageViewTransform.concatenating(.init(rotationAngle: rotation))
        if gestureRecognizer.state == .ended {
            lastImageViewTransform = view.transform
        }
    }
    
    private func resizeImage(_ image: UIImage) -> UIImage {
        let size = CGSize(width: 640, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1.0)))
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            picker.dismiss(animated: true)
            return
        }
        let itemProvider = result.itemProvider
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        imageFetchProgress = itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                self?.changePhoto(image)
            }
        }
        
        picker.dismiss(animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier{
        case "print":
            guard let printViewController = segue.destination as? PrintViewController else { return }
            let image = resizeImage(preview.asImage())
            printViewController.image = image
        default:
            break
        }
    }
    
}

fileprivate extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}
