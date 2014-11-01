//
//  ARPTextureManager.swift
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 20.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal

class ARPTextureManager: ARPSingletonProtocol {
   
    private var textureCache = [String: MTLTexture]()
    
    required init() {
    
    }
    
    class func className() -> String {
        return "ARPTextureManager"
    }
    
    func loadTexture(name: String!, device: MTLDevice!) -> MTLTexture? {
    
        var texture = textureCache[name]
        
        if let texture = texture {
        
            return texture
        }
        
        var texStruct = imageStruct()
        
        createImageData(name, &texStruct)
        
        if let bitmapData = texStruct.bitmapData {
        
            if texStruct.hasAlpha == false && texStruct.bitsPerPixel >= 24 {
            
                convertToRGBA(&texStruct)
            }
        
            var descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm,
                width: Int(texStruct.width),
                height: Int(texStruct.height),
                mipmapped: false)
            
            var loadedTexture = device.newTextureWithDescriptor(descriptor)
            
            loadedTexture.replaceRegion(
                MTLRegionMake2D(0, 0, Int(texStruct.width),Int(texStruct.height)),
                mipmapLevel: 0,
                withBytes: texStruct.bitmapData!,
                bytesPerRow: Int(texStruct.width * texStruct.bitsPerPixel / 8))
            
            free(texStruct.bitmapData!)
            
            textureCache[name] = loadedTexture
            
            return loadedTexture
        }
        
        return nil
    }

    func loadCubeTexture(name: String!, device: MTLDevice!) -> MTLTexture? {
    
        var texture = textureCache[name]
        
        if let texture = texture {
            
            return texture
        }
        
        var texStruct = imageStruct()
        
        createImageData(name, &texStruct)
        
        if let bitmapData = texStruct.bitmapData {
            
            if texStruct.hasAlpha == false && texStruct.bitsPerPixel >= 24 {
                
                convertToRGBA(&texStruct)
            }
        
            var bytesPerImage = Int(texStruct.width * texStruct.width * 4)
            
            var descriptor = MTLTextureDescriptor.textureCubeDescriptorWithPixelFormat(.RGBA8Unorm,
                size: Int(texStruct.width),
                mipmapped: false)
            
            var loadedTexture = device.newTextureWithDescriptor(descriptor)
            
            for index in 0...5 {
                
                loadedTexture.replaceRegion(
                    MTLRegionMake2D(0, 0, Int(texStruct.width),Int(texStruct.height)),
                    mipmapLevel: 0,
                    slice: Int(index),
                    withBytes: (texStruct.bitmapData!) + Int(index * bytesPerImage),
                    bytesPerRow: Int(texStruct.width) * 4,
                    bytesPerImage: bytesPerImage)
            }
            
            free(texStruct.bitmapData!)

            textureCache[name] = loadedTexture
            
            return loadedTexture
        }
        
        return nil
    }
}

