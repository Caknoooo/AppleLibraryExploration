import SwiftUI
import SpriteKit
import AVFoundation

class DDRGameScene: SKScene {
    private var targetZone: SKShapeNode!
    private var scoreLabel: SKLabelNode!
    private var gameObjects: [SKShapeNode] = []
    private var score = 0
    private var gameSpeed: TimeInterval = 2.0
    private var lastSpawnTime: TimeInterval = 0
    private var spawnInterval: TimeInterval = 1.5
    private var audioPlayer: AVAudioPlayer?
    private var musicStartTime: TimeInterval = 0
    private var beatMap: [(time: TimeInterval, color: UIColor, intensity: CGFloat, type: ObjectType)] = []
    private var nextBeatIndex = 0
    private var colors: [UIColor] = [.systemBlue, .systemRed, .systemGreen, .systemYellow, .systemPurple, .systemOrange]
    private var isHolding = false
    private var holdStartTime: TimeInterval = 0
    private var currentHoldObject: SKShapeNode?
    
    enum ObjectType {
        case tap
        case hold(duration: TimeInterval)
        case pause
    }
    
    override func didMove(to view: SKView) {
        setupScene()
        setupTargetZone()
        setupScoreLabel()
        setupMusic()
        generateBeatMap()
    }
    
    private func setupScene() {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)
        physicsWorld.gravity = CGVector.zero
        
        addBackgroundEffects()
    }
    
    private func addBackgroundEffects() {
        for i in 0...20 {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: CGFloat(i) * 30))
            path.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * 30))
            line.path = path
            line.strokeColor = SKColor(white: 0.1, alpha: 0.3)
            line.lineWidth = 1
            line.zPosition = -10
            addChild(line)
        }
        
        let centerLine = SKShapeNode()
        let centerPath = CGMutablePath()
        centerPath.move(to: CGPoint(x: size.width / 2, y: 0))
        centerPath.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        centerLine.path = centerPath
        centerLine.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.4)
        centerLine.lineWidth = 2
        centerLine.zPosition = -5
        addChild(centerLine)
        
        addFloatingParticles()
    }
    
    private func addFloatingParticles() {
        for _ in 0..<15 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            particle.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.5)
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            particle.zPosition = -8
            
            let moveAction = SKAction.moveBy(
                x: CGFloat.random(in: -50...50),
                y: CGFloat.random(in: -50...50),
                duration: TimeInterval.random(in: 3...6)
            )
            let reverseAction = moveAction.reversed()
            let sequence = SKAction.sequence([moveAction, reverseAction])
            let repeatAction = SKAction.repeatForever(sequence)
            
            particle.run(repeatAction)
            addChild(particle)
        }
    }
    
    private func setupTargetZone() {
        let zoneHeight: CGFloat = 80
        let zoneWidth: CGFloat = 220
        
        targetZone = SKShapeNode(rectOf: CGSize(width: zoneWidth, height: zoneHeight), cornerRadius: 15)
        targetZone.fillColor = SKColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 0.2)
        targetZone.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.8)
        targetZone.lineWidth = 3
        targetZone.position = CGPoint(x: size.width / 2, y: zoneHeight)
        targetZone.name = "targetZone"
        
        targetZone.glowWidth = 5
        
        addChild(targetZone)
        
        let borderEffect = SKShapeNode(rectOf: CGSize(width: zoneWidth + 10, height: zoneHeight + 10), cornerRadius: 20)
        borderEffect.fillColor = .clear
        borderEffect.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 0.6)
        borderEffect.lineWidth = 2
        borderEffect.position = CGPoint(x: 0, y: 0)
        borderEffect.zPosition = -1
        
        let pulseAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 1.0),
                SKAction.scale(to: 1.0, duration: 1.0)
            ])
        )
        borderEffect.run(pulseAction)
        targetZone.addChild(borderEffect)
        
        let tapLabel = SKLabelNode(text: "TARGET ZONE")
        tapLabel.fontName = "Helvetica-Bold"
        tapLabel.fontSize = 14
        tapLabel.fontColor = SKColor(red: 0.8, green: 1.0, blue: 0.9, alpha: 1.0)
        tapLabel.position = CGPoint(x: 0, y: 0)
        targetZone.addChild(tapLabel)
        
        addCornerIndicators()
    }
    
    private func addCornerIndicators() {
        let corners = [
            CGPoint(x: -100, y: -30), CGPoint(x: 100, y: -30),
            CGPoint(x: -100, y: 30), CGPoint(x: 100, y: 30)
        ]
        
        for corner in corners {
            let indicator = SKShapeNode(rectOf: CGSize(width: 15, height: 3), cornerRadius: 1.5)
            indicator.fillColor = SKColor(red: 0.0, green: 1.0, blue: 0.6, alpha: 0.8)
            indicator.strokeColor = .clear
            indicator.position = corner
            indicator.zPosition = 1
            
            let fadeAction = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.3, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
            )
            indicator.run(fadeAction)
            targetZone.addChild(indicator)
        }
    }
    
    private func setupScoreLabel() {
        let scoreBg = SKShapeNode(rectOf: CGSize(width: 120, height: 40), cornerRadius: 20)
        scoreBg.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.8)
        scoreBg.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8)
        scoreBg.lineWidth = 2
        scoreBg.position = CGPoint(x: 80, y: size.height - 100)
        addChild(scoreBg)
        
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "Helvetica-Bold"
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        scoreLabel.position = CGPoint(x: 80, y: size.height - 105)
        addChild(scoreLabel)
    }
    
    private func setupMusic() {
        guard let url = Bundle.main.url(forResource: "attention", withExtension: "mp3") else {
            print("Music file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            musicStartTime = CACurrentMediaTime()
        } catch {
            print("Error playing music: \(error)")
        }
    }
    
    private func generateBeatMap() {
        let bpm: Double = 120
        let beatInterval = 60.0 / bpm
        let songDuration: Double = 180
        var currentTime: Double = 2.0
        let minimumGap: Double = 1.5
        
        while currentTime < songDuration {
            let intensity = generateIntensityForTime(currentTime)
            let color = selectColorForIntensity(intensity)
            let objectType = determineObjectType(intensity, currentTime: currentTime)
            
            switch objectType {
            case .tap:
                beatMap.append((time: currentTime, color: color, intensity: intensity, type: objectType))
                currentTime += max(minimumGap, beatInterval)
            case .hold(let duration):
                beatMap.append((time: currentTime, color: color, intensity: intensity, type: objectType))
                currentTime += duration + minimumGap + beatInterval
            case .pause:
                currentTime += beatInterval * 3
            }
            
            if Int(currentTime / beatInterval) % 8 == 0 {
                currentTime += beatInterval * 2
            }
        }
        
        beatMap.sort { $0.time < $1.time }
    }
    
    private func generateIntensityForTime(_ time: Double) -> CGFloat {
        let beatIndex = Int(time / (60.0 / 120.0))
        let cycle = beatIndex % 32
        
        switch cycle {
        case 0, 8, 16, 24:
            return 1.0
        case 4, 12, 20, 28:
            return 0.8
        case 2, 6, 10, 14, 18, 22, 26, 30:
            return 0.6
        default:
            return CGFloat.random(in: 0.3...0.5)
        }
    }
    
    private func determineObjectType(_ intensity: CGFloat, currentTime: Double) -> ObjectType {
        let random = Float.random(in: 0...1)
        
        if intensity > 0.9 && random < 0.3 {
            return .hold(duration: 1.0)
        } else if intensity < 0.4 && random < 0.2 {
            return .pause
        } else {
            return .tap
        }
    }
    
    private func selectColorForIntensity(_ intensity: CGFloat) -> UIColor {
        switch intensity {
        case 0.9...1.0:
            return .systemRed
        case 0.7..<0.9:
            return .systemOrange
        case 0.5..<0.7:
            return .systemYellow
        default:
            return colors.randomElement()!
        }
    }
    
    private func checkBeatSpawning(_ currentTime: TimeInterval) {
        let gameTime = currentTime - musicStartTime
        
        while nextBeatIndex < beatMap.count {
            let beat = beatMap[nextBeatIndex]
            
            if gameTime >= beat.time - 2.0 {
                switch beat.type {
                case .tap:
                    spawnFallingObject(color: beat.color, intensity: beat.intensity, type: .tap)
                case .hold(let duration):
                    spawnFallingObject(color: beat.color, intensity: beat.intensity, type: .hold(duration: duration))
                case .pause:
                    break
                }
                nextBeatIndex += 1
            } else {
                break
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        checkBeatSpawning(currentTime)
        updateFallingObjects()
        removeOffscreenObjects()
        
        if nextBeatIndex >= beatMap.count && gameObjects.isEmpty {
            endGame()
        }
    }
    
    private func spawnFallingObject(color: UIColor, intensity: CGFloat, type: ObjectType) {
        let baseSize: CGFloat = 65
        let objectSize = baseSize * (0.8 + intensity * 0.4)
        
        var object: SKShapeNode
        
        switch type {
        case .tap:
            object = createHexagon(size: objectSize)
            object.name = "tapObject"
            
            let innerGlow = createHexagon(size: objectSize * 0.7)
            innerGlow.fillColor = color.withAlphaComponent(0.6)
            innerGlow.strokeColor = .clear
            innerGlow.zPosition = -1
            object.addChild(innerGlow)
            
        case .hold(let duration):
            let holdHeight = objectSize * 1.5 + CGFloat(duration * 50)
            object = SKShapeNode(rectOf: CGSize(width: objectSize, height: holdHeight), cornerRadius: objectSize/6)
            object.name = "holdObject"
            
            let holdPattern = createHoldPattern(width: objectSize, height: holdHeight)
            holdPattern.zPosition = -1
            object.addChild(holdPattern)
            
            let holdIcon = createHoldIcon()
            holdIcon.position = CGPoint(x: 0, y: holdHeight/3)
            object.addChild(holdIcon)
            
        case .pause:
            return
        }
        
        object.fillColor = color
        object.strokeColor = .white
        object.lineWidth = intensity > 0.8 ? 3 : 2
        object.position = CGPoint(x: size.width / 2, y: size.height + objectSize * 2)
        
        let shadow = object.copy() as! SKShapeNode
        shadow.fillColor = .black
        shadow.strokeColor = .clear
        shadow.alpha = 0.3
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = -2
        object.addChild(shadow)
        
        if intensity > 0.8 {
            object.glowWidth = 6
            
            let energyPulse = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.15),
                    SKAction.scale(to: 1.0, duration: 0.15)
                ])
            )
            object.run(energyPulse)
            
            addEnergyParticles(to: object)
        } else {
            object.glowWidth = 3
        }
        
        object.alpha = 0
        object.setScale(0.5)
        let appearAction = SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        object.run(appearAction)
        
        gameObjects.append(object)
        addChild(object)
    }
    
    private func createHexagon(size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        let radius = size / 2
        let centerX: CGFloat = 0
        let centerY: CGFloat = 0
        
        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        let hexagon = SKShapeNode(path: path)
        return hexagon
    }
    
    private func createHoldPattern(width: CGFloat, height: CGFloat) -> SKNode {
        let container = SKNode()
        
        for i in 0..<4 {
            let line = SKShapeNode(rectOf: CGSize(width: width - 10, height: 2), cornerRadius: 1)
            line.fillColor = .white
            line.alpha = 0.4
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: CGFloat(i - 2) * 15)
            
            let flowAction = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.8, duration: 0.5),
                    SKAction.fadeAlpha(to: 0.2, duration: 0.5)
                ])
            )
            line.run(flowAction)
            container.addChild(line)
        }
        
        return container
    }
    
    private func createHoldIcon() -> SKNode {
        let container = SKNode()
        
        let bar1 = SKShapeNode(rectOf: CGSize(width: 4, height: 16), cornerRadius: 2)
        bar1.fillColor = .white
        bar1.position = CGPoint(x: -6, y: 0)
        
        let bar2 = SKShapeNode(rectOf: CGSize(width: 4, height: 16), cornerRadius: 2)
        bar2.fillColor = .white
        bar2.position = CGPoint(x: 6, y: 0)
        
        container.addChild(bar1)
        container.addChild(bar2)
        
        return container
    }
    
    private func addEnergyParticles(to object: SKShapeNode) {
        for i in 0..<6 {
            let particle = SKShapeNode(circleOfRadius: 2)
            particle.fillColor = .white
            particle.strokeColor = .clear
            particle.alpha = 0.8
            
            let angle = CGFloat(i) * CGFloat.pi / 3
            let radius: CGFloat = 40
            let orbitalPath = UIBezierPath(
                arcCenter: CGPoint.zero,
                radius: radius,
                startAngle: angle,
                endAngle: angle + CGFloat.pi * 2,
                clockwise: true
            )
            
            let followPath = SKAction.follow(
                orbitalPath.cgPath,
                asOffset: false,
                orientToPath: false,
                duration: 2.0
            )
            let repeatPath = SKAction.repeatForever(followPath)
            
            particle.position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            particle.run(repeatPath)
            object.addChild(particle)
        }
    }
    
    private func updateFallingObjects() {
        for object in gameObjects {
            object.position.y -= CGFloat(gameSpeed * 60 / 60)
        }
    }
    
    private func endGame() {
        audioPlayer?.stop()
        
        let gameOverLabel = SKLabelNode(text: "GAME OVER")
        gameOverLabel.fontName = "Arial-Bold"
        gameOverLabel.fontSize = 32
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(gameOverLabel)
        
        let finalScoreLabel = SKLabelNode(text: "Final Score: \(score)")
        finalScoreLabel.fontName = "Arial-Bold"
        finalScoreLabel.fontSize = 24
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        addChild(finalScoreLabel)
    }
    
    private func removeOffscreenObjects() {
        gameObjects.removeAll { object in
            if object.position.y < -50 {
                if object == currentHoldObject {
                    endHold()
                }
                object.removeFromParent()
                updateScore(-1)
                return true
            }
            return false
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isHolding {
            return
        }
        
        checkForHit(at: location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isHolding {
            endHold()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isHolding {
            endHold()
        }
    }
    
    private func checkForHit(at location: CGPoint) {
        let targetZoneFrame = targetZone.frame
        
        for (index, object) in gameObjects.enumerated().reversed() {
            let objectFrame = object.frame
            
            if targetZoneFrame.intersects(objectFrame) {
                if object.name == "holdObject" {
                    startHold(object: object, index: index)
                    return
                } else if object.name == "tapObject" {
                    createHitEffect(at: object.position)
                    object.removeFromParent()
                    gameObjects.remove(at: index)
                    updateScore(10)
                    return
                }
            }
        }
        
        updateScore(-5)
        createMissEffect(at: location)
    }
    
    private func startHold(object: SKShapeNode, index: Int) {
        isHolding = true
        holdStartTime = CACurrentMediaTime()
        currentHoldObject = object
        
        object.fillColor = object.fillColor.withAlphaComponent(0.7)
        
        let holdIndicator = SKShapeNode(circleOfRadius: 40)
        holdIndicator.fillColor = .clear
        holdIndicator.strokeColor = .cyan
        holdIndicator.lineWidth = 3
        holdIndicator.name = "holdIndicator"
        holdIndicator.position = CGPoint.zero
        object.addChild(holdIndicator)
        
        let pulseAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3)
            ])
        )
        holdIndicator.run(pulseAction)
        
        targetZone.strokeColor = .cyan
        targetZone.lineWidth = 6
        
        createHoldStartEffect(at: object.position)
    }
    
    private func endHold() {
        guard let holdObject = currentHoldObject else { return }
        
        let holdDuration = CACurrentMediaTime() - holdStartTime
        let requiredDuration: Double = 1.0
        
        if holdDuration >= requiredDuration * 0.8 {
            updateScore(20)
            createHoldSuccessEffect(at: holdObject.position)
        } else {
            updateScore(-10)
            createHoldFailEffect(at: holdObject.position)
        }
        
        holdObject.removeFromParent()
        if let index = gameObjects.firstIndex(of: holdObject) {
            gameObjects.remove(at: index)
        }
        
        isHolding = false
        currentHoldObject = nil
        
        targetZone.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.8)
        targetZone.lineWidth = 3
    }
    
    private func createHoldStartEffect(at position: CGPoint) {
        let startLabel = SKLabelNode(text: "HOLD!")
        startLabel.fontName = "Arial-Bold"
        startLabel.fontSize = 16
        startLabel.fontColor = .cyan
        startLabel.position = CGPoint(x: position.x, y: position.y + 50)
        addChild(startLabel)
        
        let fade = SKAction.fadeOut(withDuration: 0.5)
        startLabel.run(SKAction.sequence([fade, SKAction.removeFromParent()]))
    }
    
    private func createHoldSuccessEffect(at position: CGPoint) {
        let successLabel = SKLabelNode(text: "EXCELLENT!")
        successLabel.fontName = "Arial-Bold"
        successLabel.fontSize = 20
        successLabel.fontColor = .cyan
        successLabel.position = CGPoint(x: position.x, y: position.y + 40)
        addChild(successLabel)
        
        for i in 0..<12 {
            let particle = SKShapeNode(circleOfRadius: 4)
            particle.fillColor = .cyan
            particle.strokeColor = .clear
            particle.position = position
            addChild(particle)
            
            let angle = CGFloat(i) * CGFloat.pi / 6
            let distance: CGFloat = 120
            let targetPosition = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            let moveAction = SKAction.move(to: targetPosition, duration: 0.6)
            let fadeOut = SKAction.fadeOut(withDuration: 0.6)
            particle.run(SKAction.sequence([
                SKAction.group([moveAction, fadeOut]),
                SKAction.removeFromParent()
            ]))
        }
        
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.7)
        let fade = SKAction.fadeOut(withDuration: 0.7)
        successLabel.run(SKAction.sequence([
            SKAction.group([moveUp, fade]),
            SKAction.removeFromParent()
        ]))
    }
    
    private func createHoldFailEffect(at position: CGPoint) {
        let failLabel = SKLabelNode(text: "TOO SHORT!")
        failLabel.fontName = "Arial-Bold"
        failLabel.fontSize = 16
        failLabel.fontColor = .red
        failLabel.position = CGPoint(x: position.x, y: position.y + 40)
        addChild(failLabel)
        
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -5, y: 0, duration: 0.1),
            SKAction.moveBy(x: 10, y: 0, duration: 0.1),
            SKAction.moveBy(x: -5, y: 0, duration: 0.1)
        ])
        
        failLabel.run(SKAction.sequence([
            shake,
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    private func addIntensityEffect(to object: SKShapeNode, intensity: CGFloat) {
        if intensity > 0.9 {
            let sparkles = createSparkleEffect()
            sparkles.position = CGPoint.zero
            object.addChild(sparkles)
        } else if intensity > 0.7 {
            let glow = SKShapeNode(circleOfRadius: 40)
            glow.fillColor = object.fillColor.withAlphaComponent(0.3)
            glow.strokeColor = .clear
            glow.zPosition = -1
            glow.position = CGPoint.zero
            object.addChild(glow)
            
            let glowPulse = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.1, duration: 0.5),
                    SKAction.fadeAlpha(to: 0.3, duration: 0.5)
                ])
            )
            glow.run(glowPulse)
        }
    }
    
    private func createSparkleEffect() -> SKNode {
        let container = SKNode()
        
        for i in 0..<8 {
            let sparkle = SKShapeNode(circleOfRadius: 2)
            sparkle.fillColor = .white
            sparkle.strokeColor = .clear
            
            let angle = CGFloat(i) * (CGFloat.pi * 2) / 8
            let radius: CGFloat = 35
            sparkle.position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            
            let twinkle = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.fadeIn(withDuration: 0.3)
                ])
            )
            sparkle.run(twinkle)
            
            container.addChild(sparkle)
        }
        
        return container
    }
    
    private func createHitEffect(at position: CGPoint) {
        let effect = SKShapeNode(circleOfRadius: 30)
        effect.fillColor = .clear
        effect.strokeColor = .green
        effect.lineWidth = 3
        effect.position = position
        addChild(effect)
        
        let scaleAction = SKAction.scale(to: 2.0, duration: 0.3)
        let fadeAction = SKAction.fadeOut(withDuration: 0.3)
        let removeAction = SKAction.removeFromParent()
        
        effect.run(SKAction.sequence([
            SKAction.group([scaleAction, fadeAction]),
            removeAction
        ]))
        
        for i in 0..<6 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = .green
            particle.strokeColor = .clear
            particle.position = position
            addChild(particle)
            
            let angle = CGFloat(i) * CGFloat.pi / 3
            let distance: CGFloat = 80
            let targetPosition = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            
            let moveAction = SKAction.move(to: targetPosition, duration: 0.4)
            let fadeOut = SKAction.fadeOut(withDuration: 0.4)
            particle.run(SKAction.sequence([
                SKAction.group([moveAction, fadeOut]),
                SKAction.removeFromParent()
            ]))
        }
        
        let perfectLabel = SKLabelNode(text: "PERFECT!")
        perfectLabel.fontName = "Arial-Bold"
        perfectLabel.fontSize = 18
        perfectLabel.fontColor = .green
        perfectLabel.position = CGPoint(x: position.x, y: position.y + 40)
        addChild(perfectLabel)
        
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.5)
        let fade = SKAction.fadeOut(withDuration: 0.5)
        perfectLabel.run(SKAction.sequence([
            SKAction.group([moveUp, fade]),
            SKAction.removeFromParent()
        ]))
    }
    
    private func createMissEffect(at position: CGPoint) {
        let effect = SKShapeNode(circleOfRadius: 20)
        effect.fillColor = .clear
        effect.strokeColor = .red
        effect.lineWidth = 2
        effect.position = position
        addChild(effect)
        
        let fadeAction = SKAction.fadeOut(withDuration: 0.2)
        let removeAction = SKAction.removeFromParent()
        
        effect.run(SKAction.sequence([fadeAction, removeAction]))
        
        let missLabel = SKLabelNode(text: "MISS!")
        missLabel.fontName = "Arial-Bold"
        missLabel.fontSize = 16
        missLabel.fontColor = .red
        missLabel.position = CGPoint(x: position.x, y: position.y + 30)
        addChild(missLabel)
        
        let fade = SKAction.fadeOut(withDuration: 0.3)
        missLabel.run(SKAction.sequence([fade, SKAction.removeFromParent()]))
    }
    
    private func updateScore(_ points: Int) {
        score = max(0, score + points)
        scoreLabel.text = "Score: \(score)"
    }
}

struct DDRGameView: View {
    @State private var scene = DDRGameScene()
    
    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: configureScene(geometry))
                .ignoresSafeArea()
        }
    }
    
    private func configureScene(_ geometry: GeometryProxy) -> DDRGameScene {
        scene.size = geometry.size
        scene.scaleMode = .resizeFill
        return scene
    }
}

struct DDRGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isGameStarted = false
    
    var body: some View {
        if isGameStarted {
            DDRGameView()
        } else {
            VStack(spacing: 30) {
                Text("🎵 Rhythm Strike")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Ketuk hexagon dan hold objek panjang saat berada di target zone!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("🎮 Cara Bermain:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("🔷")
                        Text("Hexagon = TAP sekali saat di target zone")
                    }
                    
                    HStack {
                        Text("📱")
                        Text("Objek panjang = HOLD hingga habis")
                    }
                    
                    HStack {
                        Text("⏸️")
                        Text("Tidak ada objek yang menumpuk/bertabrakan")
                    }
                    
                    HStack {
                        Text("🏆")
                        Text("TAP = +10, HOLD sukses = +20 poin")
                    }
                    
                    HStack {
                        Text("❌")
                        Text("Miss = -5, Hold gagal = -10 poin")
                    }
                    
                    HStack {
                        Text("🔊")
                        Text("Pastikan volume aktif untuk pengalaman terbaik")
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.cyan.opacity(0.5), .purple.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                
                Button("🚀 MULAI GAME") {
                    isGameStarted = true
                }
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 50)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.cyan, .blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(30)
                .shadow(color: .cyan.opacity(0.3), radius: 10, x: 0, y: 5)
                .scaleEffect(isGameStarted ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isGameStarted)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
