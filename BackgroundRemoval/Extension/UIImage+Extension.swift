//
//  UIImage+Extension.swift
//  BackgroundRemoval
//
//  Created by Emre Çelik on 2.05.2022.
//

import UIKit
import VideoToolbox

extension UIImage {
    func resizedCroppedImage(newSize: CGSize) -> UIImage? {
        var ratio: CGFloat = 0
        var delta: CGFloat = 0
        var offset = CGPoint.zero
        if self.size.width > self.size.height {
            ratio = newSize.width / self.size.width
            delta = (ratio * self.size.width) - (ratio * self.size.height)
            offset = CGPoint(x: delta / 2, y: 0)
        } else {
            ratio = newSize.width / self.size.height
            delta = (ratio * self.size.height) - (ratio * self.size.width)
            offset = CGPoint(x: 0, y: delta / 2)
        }
        let clipRect = CGRect(x: -offset.x,
                              y: -offset.y,
                              width: (ratio * self.size.width) + delta,
                              height: (ratio * self.size.height) + delta)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 0.0)
        UIRectClip(clipRect)
        self.draw(in: clipRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    public func pixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(self.size.width),
                                         Int(self.size.height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: Int(self.size.width),
                                height: Int(self.size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
    
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let cgImage = cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
    
    func maskImage(withMask maskImage: UIImage) -> UIImage? {
        guard let maskRef = maskImage.cgImage else { return nil }

        let mask = CGImage(
            maskWidth: maskRef.width,
            height: maskRef.height,
            bitsPerComponent: maskRef.bitsPerComponent,
            bitsPerPixel: maskRef.bitsPerPixel,
            bytesPerRow: maskRef.bytesPerRow,
            provider: maskRef.dataProvider!,
            decode: nil,
            shouldInterpolate: false)!
        
        guard let maskSelf = self.cgImage else { return nil }
        guard let masked = maskSelf.masking(mask) else { return nil }
        let maskedImage = UIImage(cgImage: masked)
        return maskedImage

    }
    
    func invertedImage() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let ciImage = CoreImage.CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
        filter.setDefaults()
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let context = CIContext(options: nil)
        guard let outputImage = filter.outputImage else { return nil }
        guard let outputImageCopy = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: outputImageCopy, scale: self.scale, orientation: .up)
    }
}
