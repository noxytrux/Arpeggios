//
//  Utilities.swift
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 20.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import QuartzCore

let kARPDomain:String! = "ARPDemoDomain"

struct imageStruct
{
    var width : UInt = 0
    var height : UInt = 0
    var bitsPerPixel : UInt = 0
    var hasAlpha : Bool = false
    var bitmapData : UnsafeMutablePointer<Void>? = nil
}

func createImageData(name: String!,inout texInfo: imageStruct) {

    let baseImage = UIImage(named: name)
    let image: CGImageRef? = baseImage?.CGImage

    if let image = image {
    
        texInfo.width = CGImageGetWidth(image)
        texInfo.height = CGImageGetHeight(image)
        texInfo.bitsPerPixel = CGImageGetBitsPerPixel(image)
        texInfo.hasAlpha = CGImageGetAlphaInfo(image) != .None
        
        var sizeInBytes = texInfo.width * texInfo.height * texInfo.bitsPerPixel / 8
        var bytesPerRow = texInfo.width * texInfo.bitsPerPixel / 8
        
        texInfo.bitmapData = malloc(sizeInBytes)
        
        let context : CGContextRef = CGBitmapContextCreate(
            texInfo.bitmapData!,
            texInfo.width,
            texInfo.height, 8,
            bytesPerRow,
            CGImageGetColorSpace(image),
            CGImageGetBitmapInfo(image))
        
        CGContextDrawImage(
            context,
            CGRectMake(0, 0, CGFloat(texInfo.width), CGFloat(texInfo.height)),
            image)
        
    }
    
}

func convertToRGBA(inout texInfo: imageStruct) {

    assert(texInfo.bitsPerPixel == 24, "Wrong image format")

    var stride = texInfo.width * 4
    var newPixels = malloc(stride * texInfo.height)
    
    var dstPixels = UnsafeMutablePointer<UInt32>(newPixels)
    
    var r: UInt8,
        g: UInt8,
        b: UInt8,
        a: UInt8
    
        a = 255
    
    var sourceStride = texInfo.width * texInfo.bitsPerPixel / 8
    var pointer = texInfo.bitmapData!
    
    for var j : UInt = 0; j < texInfo.height; j++
    {
        for var i : UInt = 0; i < sourceStride; i+=3 {
        
            var position : Int = Int(i + (sourceStride * j))
            var srcPixel = UnsafeMutablePointer<UInt8>(pointer + position)
            
            r = srcPixel.memory
            srcPixel++
            g = srcPixel.memory
            srcPixel++
            b = srcPixel.memory
            srcPixel++
            
            dstPixels.memory = (UInt32(a) << 24 | UInt32(b) << 16 | UInt32(g) << 8 | UInt32(r) )
            dstPixels++
        }
    }
    
    if let bitmapData = texInfo.bitmapData {

        free(texInfo.bitmapData!)
    }
    
    texInfo.bitmapData = newPixels
    texInfo.bitsPerPixel = 32
    texInfo.hasAlpha = true
}



