//
//  ARPModelManager.swift
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 28.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import Metal

class ARPModelManager: ARPSingletonProtocol {

    private var modelsCache = [String: ARPModel]()
    
    required init() {
        
    }
    
    class func className() -> String {
        return "ARPModelManager"
    }
    
    func loadModel(name: String!, device: MTLDevice!) -> ARPModel? {
        
        var model = modelsCache[name]
        
        if let model = model {
            
            return model
        }
        
        var loadedModel = ARPModel()
        
        let info = loadedModel.load(name, device: device)
        
        if info.loaded == false {
        
            print("Error while loadin model: \(info.error!)");
            return nil
        }
        
        modelsCache[name] = loadedModel
        
        return loadedModel
    }

}
