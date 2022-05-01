//
//  ViewController.swift
//  BackgroundRemoval
//
//  Created by Emre Çelik on 2.05.2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet private weak var captureView: UIView!
    @IBOutlet private weak var filterImageView: UIImageView!
    
    // MARK: Camera Capture Variables
    var deviceInput: AVCaptureDeviceInput!
    let session = AVCaptureSession()
    let videoQueue = DispatchQueue(label: "video",
                                   qos: .userInteractive,
                                   attributes: [],
                                   autoreleaseFrequency: .workItem)
    let videoDataOutput = AVCaptureVideoDataOutput()
    var rootLayer: CALayer! = nil
    var previewLayer: AVCaptureVideoPreviewLayer! = nil
    
    // MARK: U2Net Model
    var model: u2netp!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        model = try? u2netp.init()
        setupVideoCaptureAndLayers()
        session.startRunning()
    }
    
    func setupVideoCaptureAndLayers() {
        let videoDevice = AVCaptureDevice.default(for: .video)
        do { deviceInput = try AVCaptureDeviceInput(device:videoDevice!) } catch { return }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        if session.canAddOutput(videoDataOutput) && session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        } else { return }
        
        session.commitConfiguration()
        
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        rootLayer = captureView.layer
        rootLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }
    
    func getFilterImage(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciimage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let croppedImage = UIImage(ciImage: ciimage).resizedCroppedImage(newSize: CGSize(width: 320, height: 320)) else { return nil }
        guard let buffer = croppedImage.pixelBuffer() else { return nil }
        let result = try? self.model?.prediction(in_0: buffer)
        guard let out_p1 = result?.out_p0, let output = UIImage(pixelBuffer: out_p1) else { return nil }
        return output
    }


}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let filterImage = getFilterImage(sampleBuffer: sampleBuffer) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.filterImageView.image = filterImage
        }
    }
}
