//
//  GameViewController.swift
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 15.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal
import QuartzCore

let maxFramesToBuffer = 3

struct sunStructure {
 
    var sunVector = Vector3()
    var sunColor = Vector3()
}

struct matrixStructure {
    
    var projMatrix = Matrix4x4()
    var viewMatrix = Matrix4x4()
    var normalMatrix = Matrix4x4()
}

class ARPMainViewController: UIViewController {
    
    internal var previousUpdateTime : CFTimeInterval = 0.0
    internal var delta : CFTimeInterval = 0.0
    
    let device = { MTLCreateSystemDefaultDevice() }()
    let metalLayer = { CAMetalLayer() }()

    var defaultLibrary: MTLLibrary! = nil
    
    //MARK: common
    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    let inflightSemaphore = dispatch_semaphore_create(maxFramesToBuffer)
    var bufferIndex = 0
    
    //MARK: matrices and sun info
   
    //vector for viewMatrix
    var eyeVec = Vector3(x: 0.0,y: 2.0,z: 3.0)
    var dirVec = Vector3(x: 0.0,y: -0.234083,z: -0.9)
    var upVec = Vector3(x: 0, y: 1, z: 0)
   
    var loadedModels =  [ARPModel]()
    
    //sun info
    var sunPosition = Vector3(x: 5.316387,y: -2.408824,z: 0)
    
    var orangeColor = Vector3(x: 1.0, y: 0.5, z: 0.0)
    var yellowColor = Vector3(x: 1.0, y: 1.0, z: 0.8)
    
    //MARK: Render states
    var pipelineStates = [String : MTLRenderPipelineState]()
    
    //MARK: uniform data
    var sunBuffer: MTLBuffer! = nil
    var cameraMatrix: Matrix4x4 = Matrix4x4()
   
    var rotationAngle: Float32 = 0.0
    
    var sunData = sunStructure()
    var matrixData = matrixStructure()

    var inverted = Matrix33()
    var rotMatrixX = Matrix33()
    var rotMatrixY = Matrix33()
    var rotMatrixZ = Matrix33()
    
    var baseStiencilState: MTLDepthStencilState! = nil
    
    override func prefersStatusBarHidden() -> Bool {
     
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        
        self.resize()
        
        view.layer.addSublayer(metalLayer)
        view.opaque = true
        view.backgroundColor = nil
        
        commandQueue = device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        defaultLibrary = device.newDefaultLibrary()
        
        ARPSingletonFactory<ARPModelManager>.sharedInstance()
        ARPSingletonFactory<ARPTextureManager>.sharedInstance()
        
        //generate shaders and descriptors
       
        preparePipelineStates()
    
        //set matrix
    
        var aspect = Float32(view.frame.size.width/view.frame.size.height)
        matrixData.projMatrix = matrix44MakePerspective(degToRad(60), aspect, 0.01, 5000)
        
        //set unifor buffers
        
        sunBuffer = device.newBufferWithBytes(&sunData, length: sizeof(sunStructure), options: nil)
        
        //load models and scene
        
        loadModels()
        
        timer = CADisplayLink(target: self, selector: Selector("renderLoop"))
        timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    func loadModels() {
    
        var palmModel = ARPSingletonFactory<ARPModelManager>.sharedInstance().loadModel("palmnew", device: device)
        
        if let palmModel = palmModel {
            
            palmModel.modelScale = 0.12
            palmModel.modelMatrix.t = Vector3()
            palmModel.modelMatrix.M.rotY(Float32(M_PI + (M_PI_4 * 0.5)))
            palmModel.setCullModeForMesh(1, mode: .None)
            
            loadedModels.append(palmModel)
        }
        
        var boxModel = ARPSingletonFactory<ARPModelManager>.sharedInstance().loadModel("box", device: device)
        
        if let boxModel = boxModel {
            
            boxModel.modelScale = 0.25
            boxModel.modelMatrix.t = Vector3(x: 2.5, y:0, z:0)
            
            loadedModels.append(boxModel)
        }
        
        var barrelModel = ARPSingletonFactory<ARPModelManager>.sharedInstance().loadModel("barrel", device: device)
        
        if let barrelModel = barrelModel {
            
            barrelModel.modelScale = 0.1
            barrelModel.modelMatrix.t = Vector3(x: -4, y:0, z:0)
            
            loadedModels.append(barrelModel)
        }
    }
    
    func preparePipelineStates() {
        
        var desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true;
        desc.depthCompareFunction = .LessEqual;
        baseStiencilState = device.newDepthStencilStateWithDescriptor(desc)
        
        
        //create all pipeline states for shaders
        var pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        var pipelineError : NSError?
        var fragmentProgram: MTLFunction?
        var vertexProgram: MTLFunction?
        
        
        //BASIC SHADER
        fragmentProgram = defaultLibrary?.newFunctionWithName("basicRenderFragment")
        vertexProgram = defaultLibrary?.newFunctionWithName("basicRenderVertex")
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        
        
        var basicState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        
        if (basicState == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }

        pipelineStates["basic"] = basicState
    }
    
    override func viewDidLayoutSubviews() {
        
        self.resize()
    }
    
    func resize() {
        
        view.contentScaleFactor = UIScreen.mainScreen().nativeScale
        metalLayer.frame = view.layer.frame
        
        var drawableSize = view.bounds.size
        drawableSize.width = drawableSize.width * CGFloat(view.contentScaleFactor)
        drawableSize.height = drawableSize.height * CGFloat(view.contentScaleFactor)
        
        metalLayer.drawableSize = drawableSize
    }
    
    deinit {
        
        timer.invalidate()
    }
    
    func renderLoop() {
        
        autoreleasepool {
            
            self.render()
        }
    }
    
    func render() {
        
        // use semaphore to encode 3 frames ahead
        dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        self.update()
        
        let commandBuffer = commandQueue.commandBuffer()
            commandBuffer.label = "Frame command buffer"
        
        let drawable = metalLayer.nextDrawable()
        
        //this one is generated on the fly as it render to our main FBO
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder?.label = "Regular pass encoder"
        renderEncoder?.setFrontFacingWinding(.CounterClockwise)
        renderEncoder?.setDepthStencilState(baseStiencilState)
    
        renderEncoder?.setVertexBuffer(sunBuffer, offset: 0, atIndex: 2)
        
        var cameraViewMatrix = Matrix34(initialize: false)
            cameraViewMatrix.setColumnMajor44(cameraMatrix)

        for model in loadedModels {
    
            //calcualte real model view matrix
            var modelViewMatrix = cameraViewMatrix * (model.modelMatrix * model.modelScale)
            
            var normalMatrix = Matrix33(other: modelViewMatrix.M)
            
            if modelViewMatrix.M.getInverse(&inverted) == true {
                
                normalMatrix.setTransposed(inverted)
            }

            //set updated buffer info
            modelViewMatrix.getColumnMajor44(&matrixData.viewMatrix)
        
            var normal4x4 = Matrix34(rot: normalMatrix, trans: Vector3(x: 0, y: 0, z: 0))
                normal4x4.getColumnMajor44(&matrixData.normalMatrix)
            
            //cannot modify single value
            var matrices = UnsafeMutablePointer<matrixStructure>(model.matrixBuffer.contents())
                matrices.memory = matrixData
            
            //memcpy(model.matrixBuffer.contents(), &matrixData, UInt(sizeof(matrixStructure)))
            
            renderEncoder?.setVertexBuffer(model.matrixBuffer, offset: 0, atIndex: 1)
            
            model.render(renderEncoder!, states: pipelineStates, shadowPass: false)
        }
        
        renderEncoder?.endEncoding()
        
        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use cpature list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.inflightSemaphore)
            }
            return
        }
        
        // bufferIndex matches the current semaphore controled frame index to ensure writing occurs at the correct region in the vertex buffer
        bufferIndex = (bufferIndex + 1) % maxFramesToBuffer;
        
        commandBuffer.presentDrawable(drawable)
        commandBuffer.commit()
    }
    
    func update() {
        
        delta = timer.timestamp - self.previousUpdateTime
        previousUpdateTime = timer.timestamp
        
        if delta > 0.3 {
            delta = 0.3
        }
        
        //update lookAt matrix
        cameraMatrix = matrix44MakeLookAt(eyeVec, eyeVec+dirVec, upVec)
    
        //udpate sun position and color
    
        sunPosition.y += Float32(delta) * 0.5
        sunPosition.x += Float32(delta) * 0.5
        
        sunData.sunVector = Vector3(x: -cosf(sunPosition.x) * sinf(sunPosition.y),
                                    y: -cosf(sunPosition.y),
                                    z: -sinf(sunPosition.x) * sinf(sunPosition.y))
        
        var sun_cosy = sunData.sunVector.y
        var factor = 0.25 + sun_cosy * 0.75
        
        sunData.sunColor = ((orangeColor * (1.0 - factor)) + (yellowColor * factor))
        
        memcpy(sunBuffer.contents(), &sunData, UInt(sizeof(sunStructure)))
        
        //update models rotation
        
        rotationAngle += Float32(delta) * 0.5
       
        rotMatrixX.rotX(rotationAngle)
        rotMatrixY.rotY(rotationAngle)
        rotMatrixZ.rotZ(rotationAngle)
        
        for (index, model) in enumerate(loadedModels) {
        
            switch(index) {
            case 2 :
                
                var localRotation = Matrix33()
                    localRotation.rotX(Float32(M_PI_2))
                
                model.modelMatrix.M = localRotation * rotMatrixZ
                
            case 1 :
                
                model.modelMatrix.M = rotMatrixX * rotMatrixY * rotMatrixZ
                
            default:
                ()
            }
        }
    }
}