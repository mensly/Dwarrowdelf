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
    
    private var target : SKSpriteNode?
    private var spinnyNode : SKShapeNode?
    
    let appId: Int32 = 141573
    let nodeId: Int64 = Int64(arc4random()) + (Int64(arc4random()) << 32)
    let queue = DispatchQueue.main
    var transport: UDTransport!
    var peers = [String:[UDLink]]()   // nodeId to links to it.
    var enabled: Bool = true {
        didSet {
            self.target?.isHidden = !enabled
        }
    }
    
    
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
        
        // Get target node from scene and store it for use later
        self.target = self.childNode(withName: "//target") as? SKSpriteNode
        
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
    
    func checkTap(atPoint pos : CGPoint) {
        guard let target = self.target, enabled else { return }
        if (target.contains(pos)) {
            let potentialLinks = Array(peers.values.flatMap { $0.first })
            if (!potentialLinks.isEmpty) {
                potentialLinks[Int(arc4random_uniform(UInt32(potentialLinks.count)))]
                    .sendMessage(message: SetEnabled(enabled: true))
                enabled = false
            }
        }
    }
    
    func touchDown(atPoint pos : CGPoint) {
        addChild(atPoint: pos, withColor: SKColor.green)
        checkTap(atPoint: pos)
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        addChild(atPoint: pos, withColor: SKColor.blue)
        checkTap(atPoint: pos)
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
            sendMessage(message: ChildModel(pos: pos, color: color))
        }
    }
    
    func sendMessage(message: Sendable) {
        for link in peers.values.flatMap({ $0.first }) {
            link.sendMessage(message: message)
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
        guard let message = parseMessage(data: frameData) else { return }
        switch (message) {
        case let model as ChildModel:
            addChild(atPoint: model.pos, withColor: model.color, shared: false)
        case let enabled as SetEnabled:
            self.enabled = enabled.enabled
            break
        default: break
        }
    }

    public func transport(_ transport: UDTransport, linkConnected link: UDLink) {
        if (peers[String(link.nodeId)] == nil) {
            peers[String(link.nodeId)] = [UDLink]()
            if (enabled) {
                if (link.nodeId < nodeId) {
                    link.sendMessage(message: SetEnabled(enabled: false))
                }
                else {
                    self.enabled = false
                }
            }
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
