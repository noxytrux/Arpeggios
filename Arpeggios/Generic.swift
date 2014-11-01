//
//  Generic.swift
//  Arpeggios
//
//  Created by Marcin Pędzimąż on 20.10.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit

protocol ARPSingletonProtocol
{
    class func className() -> String
    
    init()
}

private var singleton_map: [String : ARPSingletonProtocol] = [String : ARPSingletonProtocol]()
private var singleton_queue: dispatch_queue_t = dispatch_queue_create("com.arpeggios.singletonfactory", DISPATCH_QUEUE_SERIAL)

struct ARPSingletonFactory<T: ARPSingletonProtocol>
{
    static func sharedInstance() -> T
    {
        var dev: T?
        
        dispatch_sync(singleton_queue) {
            
            let identifier = T.className()
            var singleton: T? = singleton_map[identifier] as? T
            
            if singleton == nil {
                
                singleton = T()
                singleton_map.updateValue(singleton!, forKey: identifier)
            }
            
            dev = singleton
        }
        
        return dev!
    }
}

