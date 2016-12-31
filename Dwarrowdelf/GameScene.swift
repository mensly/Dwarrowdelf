//
//  GameScene.swift
//  Dwarrowdelf
//
//  Created by Michael Ensly on 31/12/2016.
//  Copyright © 2016 Mensly. All rights reserved.
//

import SpriteKit
import GameplayKit
import Underdark

class GameScene: SKScene, UDTransportDelegate {
    
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    
    let appId: Int32 = 141573
    let nodeId: Int64 = Int64(arc4random()) + (Int64(arc4random()) << 32)
    let queue = DispatchQueue.main
    var transport: UDTransport!
    var peers = [String:[UDLink]]()   // nodeId to links to it.
    
    deinit {
        transport?.stop()
    }
    
    override func didMove(to view: SKView) {
        if transport == nil {
            let transportKinds = [UDTransportKind.wifi.rawValue, UDTransportKind.bluetooth.rawValue]
            transport = UDUnderdark.configureTransport(withAppId: appId, nodeId: nodeId, queue: queue, kinds: transportKinds)
            transport.delegate = self
            transport.start()
        }
        
        // Get label node from scene and store it for use later
        self.label = self.childNode(withName: "//helloLabel") as? SKLabelNode
        if let label = self.label {
            label.alpha = 0.0
            label.run(SKAction.fadeIn(withDuration: 2.0))
        }
        
        // Create shape node to use during mouse interaction
        let w = (self.size.width + self.size.height) * 0.05
        self.spinnyNode = SKShapeNode.init(rectOf: CGSize.init(width: w, height: w), cornerRadius: w * 0.3)
        
        if let spinnyNode = self.spinnyNode {
            spinnyNode.lineWidth = 2.5
            
            spinnyNode.run(SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat(M_PI), duration: 1)))
            spinnyNode.run(SKAction.sequence([SKAction.wait(forDuration: 0.5),
                                              SKAction.fadeOut(withDuration: 0.5),
                                              SKAction.removeFromParent()]))
        }
    }
    
    
    func touchDown(atPoint pos : CGPoint) {
        addChild(atPoint: pos, withColor: SKColor.green)
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        addChild(atPoint: pos, withColor: SKColor.blue)
    }
    
    func touchUp(atPoint pos : CGPoint) {
        addChild(atPoint: pos, withColor: SKColor.red)
    }
    
    func addChild(atPoint pos : CGPoint, withColor color: SKColor, shared: Bool = true) {
        if let n = self.spinnyNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = color
            self.addChild(n)
        }
        if (shared) {
            for link in peers.values.flatMap({ $0.first }) {
                let model = ChildModel(pos: pos, color: color)
                link.sendFrame(model.data)
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    public func transport(_ transport: UDTransport, link: UDLink, didReceiveFrame frameData: Data) {
        let model = ChildModel(data: frameData)
        addChild(atPoint: model.pos, withColor: model.color, shared: false)
    }

    public func transport(_ transport: UDTransport, linkConnected link: UDLink) {
        if (peers[String(link.nodeId)] == nil) {
            peers[String(link.nodeId)] = [UDLink]()
        }
        
        var links: [UDLink] = peers[String(link.nodeId)]!
        links.append(link)
        links.sort { (link1, link2) -> Bool in
            return link1.priority < link2.priority
        }
        
        peers[String(link.nodeId)] = links
    }
    public func transport(_ transport: UDTransport, linkDisconnected link: UDLink) {
        guard var links = peers[String(link.nodeId)] else {
            return
        }
        
        links = links.filter() { $0 !== link }
        
        if (links.isEmpty) {
            peers.removeValue(forKey: String(link.nodeId))
        } else {
            peers[String(link.nodeId)] = links
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
}

struct ChildModel {
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
