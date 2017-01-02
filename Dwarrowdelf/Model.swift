//
//  Model.swift
//  Dwarrowdelf
//
//  Created by Michael Ensly on 31/12/2016.
//  Copyright © 2016 Mensly. All rights reserved.
//

import Foundation
import SpriteKit
import Underdark

enum MessageType: UInt8 {
    case ChildModel
    case SetEnabled
}

protocol Sendable {
    var type: MessageType { get }
    var data: Data { get }
}

func parseMessage(data: Data) -> Any? {
    guard let type = MessageType.init(rawValue: data[0]) else { return nil }
    let payload = data.subdata(in: 1..<data.count)
    switch type {
        case MessageType.ChildModel:
            return ChildModel(data: payload)
        case MessageType.SetEnabled:
            return SetEnabled(data: payload)
    }
}

extension UDLink {
    func sendMessage(message: Sendable) {
        sendFrame(Data(bytes: [message.type.rawValue]) + message.data)
    }
}

struct SetEnabled: Sendable {
    let type = MessageType.SetEnabled
    let enabled: Bool
    init (enabled: Bool) {
        self.enabled = enabled
    }
    init(data: Data) {
        self.enabled = (data[0] != 0)
    }
    var data: Data {
        return Data(bytes: [enabled ? 1 : 0])
    }
}

struct ChildModel: Sendable {
    let type = MessageType.ChildModel
    let x: Float32
    let y: Float32
    let r: Float32
    let g: Float32
    let b: Float32
    let a: Float32
    
    init(pos : CGPoint, color: SKColor) {
        x = Float32(pos.x)
        y = Float32(pos.y)
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.r = Float32(r)
        self.g = Float32(g)
        self.b = Float32(b)
        self.a = Float32(a)
    }
    
    init(data: Data) {
        var floats = [Float32](repeating: 0, count:6)
        _ = data.copyBytes(to: UnsafeMutableBufferPointer.init(
            start: &floats, count: floats.count))
        x = floats[0]
        y = floats[1]
        r = floats[2]
        g = floats[3]
        b = floats[4]
        a = floats[5]
    }
    
    var pos: CGPoint { return CGPoint(x: CGFloat(x), y: CGFloat(y)) }
    var color: SKColor { return SKColor(colorLiteralRed: Float(r),
                                        green: Float(g),
                                        blue: Float(b),
                                        alpha: Float(a)) }
    var data: Data {
        var floats = [x,y,r,g,b,a]
        return Data(buffer: UnsafeBufferPointer.init(start: &floats, count: floats.count))
    }
}
