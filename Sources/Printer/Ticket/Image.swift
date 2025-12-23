//
//  Image.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import UIKit

public protocol Image {
    var ticketImage: CGImage { get }
}

extension Image {

  var ticketData: Data? {
    // Assuming ticketImage is a CGImage property available in your scope
    let width = ticketImage.width
    let height = ticketImage.height

    if let grayData = convertImageToGray(ticketImage) {
      // 1. Thresholding: Convert grayscale to 0s and 1s
      if let binaryImageData = format_K_threshold(orgpixels: grayData, xsize: width, ysize: height) {

        // 2. Convert to ESC/POS Commands
        let data = eachLinePixToCmd(src: binaryImageData, nWidth: width, nHeight: height, nMode: 0)

        // FIX: The final size is simply the count of the generated array.
        // Manual count calculations often fail due to header bytes and padding.
        return Data(data)
      }
    }
    return nil
  }

  // ... convertImageToGray remains mostly the same, but ensure RGBA32 is defined ...

  private func format_K_threshold(orgpixels: [UInt8], xsize: Int, ysize: Int) -> [UInt8]? {
    var despixels = [UInt8]()
    var graytotal: Int = 0

    // Calculate average for dynamic thresholding
    for pixel in orgpixels {
      graytotal += Int(pixel)
    }

    let grayave = graytotal / (xsize * ysize)

    // Binarize
    for pixel in orgpixels {
      // Printer logic: 1 is Black (ink), 0 is White (paper)
      despixels.append(Int(pixel) > grayave ? 0 : 1)
    }
    return despixels
  }

  private func eachLinePixToCmd(src: [UInt8], nWidth: Int, nHeight: Int, nMode: Int) -> [UInt8] {
    var result = [UInt8]()
    let nBytesPerLine = (nWidth + 7) / 8

    for y in 0..<nHeight {
      // 1. Add Line Header (ESC/POS: GS v 0 ...)
      // xl/xH are width in bytes, yl/yH are height in dots (set to 1 dot high per command)
      let header = ESC_POSCommand.beginPrintImage(
        xl: UInt8(nBytesPerLine & 0xff),
        xH: UInt8((nBytesPerLine >> 8) & 0xff),
        yl: UInt8(1),
        yH: UInt8(0)
      ).rawValue
      result.append(contentsOf: header)

      // 2. Pack bits for this specific row
      for byteIndex in 0..<nBytesPerLine {
        var currentByte: UInt8 = 0

        for bitIndex in 0..<8 {
          let pixelX = (byteIndex * 8) + bitIndex

          // Boundary Check: If width is 300, pixelX 300-303 will be ignored (padded white)
          if pixelX < nWidth {
            let srcIndex = (y * nWidth) + pixelX
            if src[srcIndex] == 1 {
              // Set bit (7 is leftmost bit, 0 is rightmost)
              currentByte |= (1 << (7 - bitIndex))
            }
          }
        }
        result.append(currentByte)
      }
    }
    return result
  }
}

extension Image {
    private func convertImageToGray(_ inputCGImage: CGImage) -> [UInt8]? {
        
        let kRed: Int = 1
        let kGreen: Int = 2
        let kBlue: Int = 4
        let colors: Int = kGreen | kBlue | kRed
        
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context.data else {
            print("unable to get context data")
            return nil
        }
        
        var m_imageData = [UInt8]()
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                var rgbPixel = pixelBuffer[offset]
                var sum: UInt32 = 0
                var count: UInt32 = 0
                
                // ignoring transperent or light color
                if rgbPixel == .clear || rgbPixel.color < 100 {
                    rgbPixel = .white
                }
                
                if colors & kRed != 0 {
                    sum += (rgbPixel.color >> 24) & 255
                    count += 1
                }
                if colors & kGreen != 0 {
                    sum += (rgbPixel.color >> 16) & 255
                    count += 1
                }
                if colors & kBlue != 0 {
                    sum += (rgbPixel.color >> 8) & 255
                    count += 1
                }
                m_imageData.append(UInt8(sum / count))
                //pixelBuffer[offset].color = sum
            }
        }
        
        //let outputCGImage = context.makeImage()!
        //let outputImage = UIImage(cgImage: outputCGImage, scale: (i?.scale)!, orientation: (i?.imageOrientation)!)
        return m_imageData
    }
}

private struct RGBA32: Equatable {
    var color: UInt32
    
    var redComponent: UInt8 {
        return UInt8((color >> 24) & 255)
    }
    
    var greenComponent: UInt8 {
        return UInt8((color >> 16) & 255)
    }
    
    var blueComponent: UInt8 {
        return UInt8((color >> 8) & 255)
    }
    
    var alphaComponent: UInt8 {
        return UInt8((color >> 0) & 255)
    }
    
    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let red   = UInt32(red)
        let green = UInt32(green)
        let blue  = UInt32(blue)
        let alpha = UInt32(alpha)
        color = (red << 24) | (green << 16) | (blue << 8) | (alpha << 0)
    }
    
    static let red     = RGBA32(red: 255, green: 0,   blue: 0,   alpha: 255)
    static let green   = RGBA32(red: 0,   green: 255, blue: 0,   alpha: 255)
    static let blue    = RGBA32(red: 0,   green: 0,   blue: 255, alpha: 255)
    static let white   = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
    static let black   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 255)
    static let magenta = RGBA32(red: 255, green: 0,   blue: 255, alpha: 255)
    static let yellow  = RGBA32(red: 255, green: 255, blue: 0,   alpha: 255)
    static let cyan    = RGBA32(red: 0,   green: 255, blue: 255, alpha: 255)
    static let clear   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 0)
    
    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    
    static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
        return lhs.color == rhs.color
    }
}

//
extension UIImage: Image {
    public var ticketImage: CGImage {
        guard let image = cgImage else {
            fatalError("can't get cgimage ref.")
        }
        return image
    }
}

/// convert UIView to image
/// can use webview print html.
extension UIView: Image {
    public var ticketImage: CGImage {
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }.ticketImage
        } else {
            UIGraphicsBeginImageContext(frame.size)
            defer {
                UIGraphicsEndImageContext()
            }
            layer.render(in: UIGraphicsGetCurrentContext()!)
            guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                fatalError("UIGraphics Get Image Failed.")
            }
            return image.ticketImage
        }
    }
}

