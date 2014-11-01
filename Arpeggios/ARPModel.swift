//
//  ARPModel.swift
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 28.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal

let kARPModelHeder: UInt16 = 0xB3D0

struct geometryInfo {
    
    var position = Vector3()
    var normal = Vector3()
    var texCoord = Vector2()
}

struct ARPMeshData {

    //texture used to draw
    var diffuseTex: MTLTexture? = nil

    //geometry info
    var vertexBuffer: MTLBuffer? = nil
    var indexBuffer: MTLBuffer? = nil
    
    //shader
    var pipelineState: String? = nil
    
    //front back facing ?
    var cullMode: MTLCullMode = .Back
    
    var faceCount: UInt32 = 0
    var vertexCount: UInt32 = 0
}

class ARPModel {

    private var subMeshData = [ARPMeshData]()
    private var modelName: String = ""
    
    internal var modelScale: Float32 = 1.0
    internal var modelMatrix: Matrix34! = nil
    
    init() {
        
        modelMatrix  = Matrix34(initialize: true)
    }
    
    func setCullModeForMesh(atIndex: Int, mode: MTLCullMode) {
    
        var meshData = subMeshData[atIndex]
            meshData.cullMode = mode
    }
    
    //based on B3DO model file format
    func load(name: String, device: MTLDevice) -> (loaded: Bool, error: NSError?) {
    
        modelName = name
        
        var error:NSError? = nil
        var status: Bool = true
        
        var path = NSBundle.mainBundle().pathForResource(name, ofType: "gmf")
        
        if let path = path {
            
            var header:UInt16 = 0
            
            var mindex:UInt32 = 0, index:UInt32 = 0
            var c:CChar = 0
            var namestr = Array<CChar>(count: 256, repeatedValue: 0)
            
            var readStream:NSFileHandle? = NSFileHandle(forReadingAtPath: path)
            
            if let readStream = readStream {
                
                //readStream.seekToFileOffset(0)
                
                var data = readStream.readDataOfLength(sizeof(UInt16))
                    data.getBytes(&header, length: sizeof(UInt16))
                
                if header == kARPModelHeder {
                
                    var bufferCount : UInt32 = 0
                    
                    data = readStream.readDataOfLength(sizeof(UInt32))
                    data.getBytes(&bufferCount, length: sizeof(UInt32))
                    
                    for(mindex = 0; mindex < bufferCount; mindex++)
                    {
                        
                        index = 0;
                        
                        do
                        {
                            data = readStream.readDataOfLength(sizeof(CChar))
                            data.getBytes(&c, length: sizeof(CChar))
                
                            namestr[Int(index)] = c
                            index++;
                        }
                        while((c != 0) && (index < 256))
                    
                        namestr[255] = 0
                    
                        var texName = String.fromCString(namestr)!
                        
                        println("Mesh: \(texName)")
                        
                        //create current mesh Structure
                        var subMeshBuffer = ARPMeshData()
                        
                        //load texture
                        subMeshBuffer.diffuseTex = ARPSingletonFactory<ARPTextureManager>.sharedInstance().loadTexture(texName, device: device)
                        
                        if subMeshBuffer.diffuseTex == nil {
                            
                            println("Warning no texture found for: \(texName)")
                        }
                        
                        data = readStream.readDataOfLength(sizeof(UInt32))
                        data.getBytes(&subMeshBuffer.vertexCount, length:sizeof(UInt32))
                        
                        data = readStream.readDataOfLength(sizeof(UInt32))
                        data.getBytes(&subMeshBuffer.faceCount, length:sizeof(UInt32))
                        
                        var vertexData = [geometryInfo]()
                        var faceData = [UInt16](count: Int(subMeshBuffer.faceCount * 3), repeatedValue: 0)
                        
                        //load vertex data
                        for(index = 0; index < subMeshBuffer.vertexCount; index++)
                        {
                            var position = Vector3(value: 0)
                            var normal = Vector3(value: 0)
                            var coord = Vector2(value: 0)
                            
                            data = readStream.readDataOfLength(sizeof(Vector3))
                            data.getBytes(&position, length: sizeof(Vector3))
                            
                            data = readStream.readDataOfLength(sizeof(Vector2))
                            data.getBytes(&coord, length: sizeof(Vector2))
                            
                            data = readStream.readDataOfLength(sizeof(Vector3))
                            data.getBytes(&normal, length: sizeof(Vector3))
                            
                            var vertexInfo = geometryInfo()
                            
                            vertexInfo.position = position
                            vertexInfo.normal = normal
                            vertexInfo.texCoord = coord
                            
                            vertexData.append(vertexInfo)
                            
                            //println("pos: \(position) normal: \(normal) coord: \(coord)")
                        }

                        //load face indexes
                        for(index = 0; index < subMeshBuffer.faceCount; index++)
                        {
                            var px:Int32 = 0,py:Int32 = 0,pz:Int32 = 0
                            
                            data = readStream.readDataOfLength(sizeof(Int32))
                            data.getBytes(&px, length: sizeof(Int32))
                            data = readStream.readDataOfLength(sizeof(Int32))
                            data.getBytes(&py, length: sizeof(Int32))
                            data = readStream.readDataOfLength(sizeof(Int32))
                            data.getBytes(&pz, length: sizeof(Int32))
                            
                            //or move seek to + 3 * sizeof Float32
                            data = readStream.readDataOfLength(sizeof(Int32) * 3)
                            
                            faceData[Int(index * 3 + 0)] = UInt16(px)
                            faceData[Int(index * 3 + 1)] = UInt16(py)
                            faceData[Int(index * 3 + 2)] = UInt16(pz)
                            
                            //println("Face: \(px),\(py),\(pz)")
                        }
                        
                        subMeshBuffer.pipelineState = "basic" //you may want to load this from some material file
                    
                        subMeshBuffer.vertexBuffer = device.newBufferWithBytes(vertexData, length:Int(subMeshBuffer.vertexCount) * sizeof(geometryInfo), options:nil)
                        subMeshBuffer.indexBuffer = device.newBufferWithBytes(faceData, length:Int(subMeshBuffer.faceCount) * 3 * sizeof(UInt16), options: nil)
                        
                        //store geometry info
                        subMeshData.append(subMeshBuffer)
                    }//for meshindex
                    
                }
                else {
                
                    status = false
                    error = NSError(domain:kARPDomain , code: NSFileReadInvalidFileNameError, userInfo: [NSLocalizedDescriptionKey : "File does not exist."])
                }
                
                readStream.closeFile()
            }

        }
        else {
            status = false
            error = NSError(domain:kARPDomain , code: NSFileNoSuchFileError, userInfo: [NSLocalizedDescriptionKey : "File does not exist."])
        }
        
        return (status, error)
    }

    func render(encoder: MTLRenderCommandEncoder, states: [String : MTLRenderPipelineState], shadowPass: Bool) {

        encoder.pushDebugGroup("rendering: \(modelName)")
    
        for subMesh in subMeshData {
            
            var pipelineState = states[subMesh.pipelineState!]
            
            if let pipelineState = pipelineState {
            
                encoder.setRenderPipelineState(pipelineState);
                
                if shadowPass == true {
                    
                    encoder.setCullMode(.Front)
                }
                else{
                    
                    encoder.setCullMode(.None)
                }

                encoder.setFragmentTexture(subMesh.diffuseTex, atIndex: 0)
                encoder.setVertexBuffer(subMesh.vertexBuffer!, offset: 0, atIndex: 0)
        
                encoder.drawIndexedPrimitives(.Triangle,
                    indexCount: Int(subMesh.faceCount)*3,
                    indexType: .UInt16,
                    indexBuffer: subMesh.indexBuffer!,
                    indexBufferOffset: 0)
                
            }
        }
        
        encoder.popDebugGroup()
    }
}
