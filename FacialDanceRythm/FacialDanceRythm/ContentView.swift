import SwiftUI
import SpriteKit
import AVFoundation
import GameplayKit
import GameKit

struct MusicData {
    let name: String
    let fileName: String
    let bpm: Double
    let duration: Double
    let difficulty: String
}

struct LevelData {
    let id: Int
    let name: String
    let description: String
    let requiredScore: Int
    let multiplier: Double
    let background: String
}

class GameDataManager {
    static let shared = GameDataManager()
    
    let availableMusic: [MusicData] = [
        MusicData(name: "Attention", fileName: "attention", bpm: 120, duration: 180, difficulty: "Easy"),
        MusicData(name: "Electronic Beat", fileName: "electronic", bpm: 140, duration: 200, difficulty: "Medium"),
        MusicData(name: "Hardcore Rush", fileName: "hardcore", bpm: 180, duration: 160, difficulty: "Hard"),
        MusicData(name: "Classical Mix", fileName: "classical", bpm: 90, duration: 240, difficulty: "Easy"),
        MusicData(name: "Techno Power", fileName: "techno", bpm: 160, duration: 190, difficulty: "Hard")
    ]
    
    let availableLevels: [LevelData] = [
        LevelData(id: 1, name: "Easy", description: "Perfect for newcomers", requiredScore: 0, multiplier: 1.0, background: "simple")
    ]
    
    private init() {}
    
    func getHighScore() -> Int {
        return UserDefaults.standard.integer(forKey: "highScore")
    }
    
    func saveHighScore(_ score: Int) {
        let currentHigh = getHighScore()
        if score > currentHigh {
            UserDefaults.standard.set(score, forKey: "highScore")
        }
    }
    
    func isLevelUnlocked(_ level: LevelData) -> Bool {
        return getHighScore() >= level.requiredScore
    }
}

class GameKitManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?
    
    override init() {
        super.init()
        authenticateUser()
    }
    
    func authenticateUser() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                DispatchQueue.main.async {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(viewController, animated: true)
                    }
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                self.isAuthenticated = true
                self.localPlayer = GKLocalPlayer.local
            } else {
                print("GameKit authentication failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func submitScore(_ score: Int, category: String = "main_leaderboard") {
        guard isAuthenticated else { return }
        
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [category]) { error in
            if let error = error {
                print("Score submission failed: \(error.localizedDescription)")
            } else {
                print("Score submitted successfully!")
            }
        }
    }
    
    func unlockAchievement(_ identifier: String, percentComplete: Double = 100.0) {
        guard isAuthenticated else { return }
        
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percentComplete
        
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("Achievement unlock failed: \(error.localizedDescription)")
            } else {
                print("Achievement unlocked: \(identifier)")
            }
        }
    }
}

enum GameState {
    case mainMenu
    case levelSelection
    case musicSelection
    case playing
    case gameOver
    case settings
}

class GameStateMachine: ObservableObject {
    @Published var currentState: GameState = .mainMenu
    @Published var selectedLevel: LevelData?
    @Published var selectedMusic: MusicData?
    
    func transition(to newState: GameState) {
        currentState = newState
    }
    
    func selectLevel(_ level: LevelData) {
        selectedLevel = level
        transition(to: .musicSelection)
    }
    
    func selectMusic(_ music: MusicData) {
        selectedMusic = music
        transition(to: .playing)
    }
    
    func returnToMenu() {
        selectedLevel = nil
        selectedMusic = nil
        transition(to: .mainMenu)
    }
}

class DDRGameScene: SKScene {
    private var targetZone: SKShapeNode!
    private var scoreLabel: SKLabelNode!
    private var healthLabel: SKLabelNode!
    private var gameObjects: [SKShapeNode] = []
    private var score = 0
    private var health = 100
    private var consecutiveMisses = 0
    private var totalNotes = 0
    private var hitNotes = 0
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
    private var gameEnded = false
    
    var selectedLevel: LevelData?
    var selectedMusic: MusicData?
    var gameStateMachine: GameStateMachine?
    var gameKitManager: GameKitManager?
    
    private var randomSource = GKMersenneTwisterRandomSource()
    private var beatGenerator: GKShuffledDistribution!
    
    enum ObjectType {
        case tap
        case hold(duration: TimeInterval)
        case pause
    }
    
    override func didMove(to view: SKView) {
        setupRandomSource()
        setupScene()
        setupTargetZone()
        setupLabels()
        setupMusic()
        generateBeatMap()
    }
    
    private func setupRandomSource() {
        randomSource.seed = UInt64(CACurrentMediaTime() * 1000)
        beatGenerator = GKShuffledDistribution(randomSource: randomSource, lowestValue: 1, highestValue: 100)
    }
    
    private func setupScene() {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        physicsWorld.gravity = CGVector.zero
        
        addBackgroundEffects()
        addCameraArea()
    }
    
    private func addCameraArea() {
        let cameraWidth: CGFloat = 280
        let cameraHeight: CGFloat = 350
        
        let cameraFrame = SKShapeNode(rectOf: CGSize(width: cameraWidth, height: cameraHeight), cornerRadius: 20)
        cameraFrame.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 0.9)
        cameraFrame.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.8)
        cameraFrame.lineWidth = 3
        cameraFrame.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        cameraFrame.name = "cameraFrame"
        cameraFrame.zPosition = 10
        
        let cameraLabel = SKLabelNode(text: "📹 FACE TRACKING")
        cameraLabel.fontName = "Helvetica-Bold"
        cameraLabel.fontSize = 18
        cameraLabel.fontColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        cameraLabel.position = CGPoint(x: 0, y: cameraHeight/2 - 30)
        cameraFrame.addChild(cameraLabel)
        
        let instructionLabel = SKLabelNode(text: "Follow the beat with your face!")
        instructionLabel.fontName = "Helvetica"
        instructionLabel.fontSize = 14
        instructionLabel.fontColor = SKColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)
        instructionLabel.position = CGPoint(x: 0, y: cameraHeight/2 - 55)
        cameraFrame.addChild(instructionLabel)
        
        addFaceGuideOverlay(to: cameraFrame, width: cameraWidth, height: cameraHeight)
        addCornerFrames(to: cameraFrame, width: cameraWidth, height: cameraHeight)
        
        addChild(cameraFrame)
    }
    
    private func addFaceGuideOverlay(to parent: SKShapeNode, width: CGFloat, height: CGFloat) {
        let faceGuide = SKShapeNode(ellipseOf: CGSize(width: 120, height: 150))
        faceGuide.fillColor = .clear
        faceGuide.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.6, alpha: 0.6)
        faceGuide.lineWidth = 2
        faceGuide.position = CGPoint(x: 0, y: -20)
        faceGuide.name = "faceGuide"
        
        let pulseAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 1.0),
                SKAction.fadeAlpha(to: 0.8, duration: 1.0)
            ])
        )
        faceGuide.run(pulseAction)
        
        parent.addChild(faceGuide)
        
        let eyeLeft = SKShapeNode(circleOfRadius: 4)
        eyeLeft.fillColor = SKColor(red: 0.0, green: 1.0, blue: 0.6, alpha: 0.8)
        eyeLeft.position = CGPoint(x: -25, y: 10)
        eyeLeft.name = "eyeLeft"
        parent.addChild(eyeLeft)
        
        let eyeRight = SKShapeNode(circleOfRadius: 4)
        eyeRight.fillColor = SKColor(red: 0.0, green: 1.0, blue: 0.6, alpha: 0.8)
        eyeRight.position = CGPoint(x: 25, y: 10)
        eyeRight.name = "eyeRight"
        parent.addChild(eyeRight)
        
        let mouth = SKShapeNode(rectOf: CGSize(width: 20, height: 3), cornerRadius: 1.5)
        mouth.fillColor = SKColor(red: 0.0, green: 1.0, blue: 0.6, alpha: 0.8)
        mouth.position = CGPoint(x: 0, y: -30)
        mouth.name = "mouth"
        parent.addChild(mouth)
    }
    
    private func addCornerFrames(to parent: SKShapeNode, width: CGFloat, height: CGFloat) {
        let cornerPositions = [
            CGPoint(x: -width/2 + 20, y: height/2 - 20),
            CGPoint(x: width/2 - 20, y: height/2 - 20),
            CGPoint(x: -width/2 + 20, y: -height/2 + 20),
            CGPoint(x: width/2 - 20, y: -height/2 + 20)
        ]
        
        for (index, position) in cornerPositions.enumerated() {
            let corner = SKShapeNode()
            let path = CGMutablePath()
            
            let size: CGFloat = 15
            if index == 0 || index == 2 {
                path.move(to: CGPoint(x: -size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: index == 0 ? -size : size))
            } else {
                path.move(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: index == 1 ? -size : size))
            }
            
            corner.path = path
            corner.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 0.8)
            corner.lineWidth = 3
            corner.position = position
            
            let blinkAction = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.3, duration: 0.8),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.8)
                ])
            )
            corner.run(blinkAction)
            
            parent.addChild(corner)
        }
    }
    
    private func addBackgroundEffects() {
        for i in 0...15 {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: CGFloat(i) * 40))
            path.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * 40))
            line.path = path
            line.strokeColor = SKColor(white: 0.1, alpha: 0.2)
            line.lineWidth = 1
            line.zPosition = -10
            addChild(line)
        }
        
        let rhythmTrack = SKShapeNode(rectOf: CGSize(width: size.width, height: 8))
        rhythmTrack.fillColor = SKColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3)
        rhythmTrack.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.6)
        rhythmTrack.lineWidth = 2
        rhythmTrack.position = CGPoint(x: size.width / 2, y: size.height - 150)
        rhythmTrack.name = "rhythmTrack"
        rhythmTrack.zPosition = 5
        addChild(rhythmTrack)
        
        addFloatingParticles()
    }
    
    private func addFloatingParticles() {
        let particleCount = selectedLevel?.id ?? 1 * 5 + 10
        
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat(randomSource.nextUniform() * 3 + 1))
            particle.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.5)
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: CGFloat(randomSource.nextUniform()) * size.width,
                y: CGFloat(randomSource.nextUniform()) * size.height
            )
            particle.zPosition = -8
            
            let moveAction = SKAction.moveBy(
                x: CGFloat(randomSource.nextUniform() * 100 - 50),
                y: CGFloat(randomSource.nextUniform() * 100 - 50),
                duration: TimeInterval(randomSource.nextUniform() * 3 + 3)
            )
            let reverseAction = moveAction.reversed()
            let sequence = SKAction.sequence([moveAction, reverseAction])
            let repeatAction = SKAction.repeatForever(sequence)
            
            particle.run(repeatAction)
            addChild(particle)
        }
    }
    
    private func setupTargetZone() {
        let zoneHeight: CGFloat = 8
        let zoneWidth: CGFloat = 40
        
        targetZone = SKShapeNode(rectOf: CGSize(width: zoneWidth, height: zoneHeight), cornerRadius: 4)
        targetZone.fillColor = SKColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 0.8)
        targetZone.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
        targetZone.lineWidth = 2
        targetZone.position = CGPoint(x: 50, y: size.height - 150)
        targetZone.name = "targetZone"
        targetZone.zPosition = 15
        
        addChild(targetZone)
        
        let borderEffect = SKShapeNode(rectOf: CGSize(width: zoneWidth + 8, height: zoneHeight + 8), cornerRadius: 6)
        borderEffect.fillColor = .clear
        borderEffect.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 0.6)
        borderEffect.lineWidth = 1
        borderEffect.position = CGPoint(x: 0, y: 0)
        borderEffect.zPosition = -1
        
        let pulseAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 1.0),
                SKAction.scale(to: 1.0, duration: 1.0)
            ])
        )
        borderEffect.run(pulseAction)
        targetZone.addChild(borderEffect)
        
        addRhythmIndicators()
    }
    
    private func addRhythmIndicators() {
        for i in 0..<8 {
            let indicator = SKShapeNode(rectOf: CGSize(width: 2, height: 15))
            indicator.fillColor = SKColor(red: 0.0, green: 1.0, blue: 0.6, alpha: 0.4)
            indicator.strokeColor = .clear
            indicator.position = CGPoint(x: CGFloat(i * 60) + 100, y: size.height - 150)
            indicator.zPosition = 6
            
            let fadeAction = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.1, duration: 0.8),
                    SKAction.fadeAlpha(to: 0.6, duration: 0.8)
                ])
            )
            indicator.run(fadeAction)
            addChild(indicator)
        }
    }
    
    private func setupLabels() {
        let scoreBg = SKShapeNode(rectOf: CGSize(width: 180, height: 50), cornerRadius: 25)
        scoreBg.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.9)
        scoreBg.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8)
        scoreBg.lineWidth = 2
        scoreBg.position = CGPoint(x: size.width / 2, y: 80)
        scoreBg.zPosition = 20
        addChild(scoreBg)
        
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "Helvetica-Bold"
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        scoreLabel.position = CGPoint(x: size.width / 2, y: 72)
        scoreLabel.zPosition = 21
        addChild(scoreLabel)
        
        let healthBg = SKShapeNode(rectOf: CGSize(width: 120, height: 30), cornerRadius: 15)
        healthBg.fillColor = SKColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 0.9)
        healthBg.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8)
        healthBg.lineWidth = 2
        healthBg.position = CGPoint(x: size.width - 80, y: size.height - 40)
        healthBg.zPosition = 20
        addChild(healthBg)
        
        healthLabel = SKLabelNode(text: "HP: 100")
        healthLabel.fontName = "Helvetica-Bold"
        healthLabel.fontSize = 16
        healthLabel.fontColor = SKColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        healthLabel.position = CGPoint(x: size.width - 80, y: size.height - 47)
        healthLabel.zPosition = 21
        addChild(healthLabel)
    }
    
    private func setupMusic() {
        guard let music = selectedMusic,
              let url = Bundle.main.url(forResource: music.fileName, withExtension: "mp3") else {
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
        guard let music = selectedMusic, let level = selectedLevel else { return }
        
        let bpm = music.bpm
        let beatInterval = 60.0 / bpm
        let songDuration = music.duration
        var currentTime: Double = 4.0
        let levelMultiplier = level.multiplier
        
        let baseGap: Double
        if levelMultiplier <= 1.0 {
            baseGap = 2.5
        } else {
            baseGap = max(2.0, 3.0 - ((levelMultiplier - 1.0) * 0.8))
        }
        
        while currentTime < songDuration {
            let intensity = generateIntensityForTime(currentTime, levelMultiplier: levelMultiplier)
            let color = selectColorForIntensity(intensity)
            let objectType = determineObjectType(intensity, currentTime: currentTime, levelMultiplier: levelMultiplier)
            
            switch objectType {
            case .tap:
                beatMap.append((time: currentTime, color: color, intensity: intensity, type: objectType))
                totalNotes += 1
                currentTime += baseGap + (beatInterval * 0.5)
            case .hold(let duration):
                beatMap.append((time: currentTime, color: color, intensity: intensity, type: objectType))
                totalNotes += 1
                currentTime += duration + baseGap * 1.5 + beatInterval
            case .pause:
                currentTime += beatInterval * max(3.0, 6 - levelMultiplier * 0.5)
            }
            
            if Int(currentTime / beatInterval) % 16 == 0 {
                currentTime += beatInterval * max(2.0, 4 - levelMultiplier * 0.5)
            }
        }
        
        beatMap.sort { $0.time < $1.time }
    }
    
    private func generateIntensityForTime(_ time: Double, levelMultiplier: Double) -> CGFloat {
        let beatIndex = Int(time / (60.0 / (selectedMusic?.bpm ?? 120)))
        let cycle = beatIndex % 32
        let baseIntensity: CGFloat
        
        switch cycle {
        case 0, 8, 16, 24:
            baseIntensity = 1.0
        case 4, 12, 20, 28:
            baseIntensity = 0.8
        case 2, 6, 10, 14, 18, 22, 26, 30:
            baseIntensity = 0.6
        default:
            baseIntensity = CGFloat(randomSource.nextUniform() * 0.2 + 0.3)
        }
        
        return min(1.0, baseIntensity * CGFloat(levelMultiplier))
    }
    
    private func determineObjectType(_ intensity: CGFloat, currentTime: Double, levelMultiplier: Double) -> ObjectType {
        let randomValue = beatGenerator.nextInt()
        let holdChance = Int(35 + levelMultiplier * 15)
        let pauseChance = max(8, Int(25 - levelMultiplier * 8))
        
        if intensity > 0.65 && randomValue <= holdChance && randomValue % 3 == 0 {
            return .hold(duration: max(1.2, 2.2 - levelMultiplier * 0.4))
        } else if intensity < 0.35 && randomValue <= pauseChance {
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
            return colors[randomSource.nextInt(upperBound: colors.count)]
        }
    }
    
    private func checkBeatSpawning(_ currentTime: TimeInterval) {
        let gameTime = currentTime - musicStartTime
        let levelMultiplier = selectedLevel?.multiplier ?? 1.0
        let spawnDelay = max(2.8, 4.0 - (levelMultiplier * 0.4))
        
        while nextBeatIndex < beatMap.count {
            let beat = beatMap[nextBeatIndex]
            
            if gameTime >= beat.time - spawnDelay {
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
        guard !gameEnded else { return }
        
        checkBeatSpawning(currentTime)
        updateFallingObjects()
        removeOffscreenObjects()
        
        if health <= 0 && !gameEnded {
            endGameWithResult(won: false)
        } else if nextBeatIndex >= beatMap.count && gameObjects.isEmpty && !gameEnded {
            let accuracy = totalNotes > 0 ? Double(hitNotes) / Double(totalNotes) : 0
            endGameWithResult(won: accuracy >= 0.7)
        }
    }
    
    private func spawnFallingObject(color: UIColor, intensity: CGFloat, type: ObjectType) {
        guard !gameEnded else { return }
        
        let objectSize: CGFloat = 80
        let spawnX = size.width + objectSize * 1.5
        let minDistance = objectSize * 2.2
        
        for existingObject in gameObjects {
            if abs(existingObject.position.x - spawnX) < minDistance {
                return
            }
        }
        
        var object: SKShapeNode
        let artboardNumber = randomSource.nextInt(upperBound: 13) + 4
        
        switch type {
        case .tap:
            object = SKShapeNode(circleOfRadius: objectSize / 2)
            object.name = "tapObject"
            
        case .hold(let duration):
            let holdWidth = max(objectSize * 1.5, objectSize + CGFloat(duration * 18))
            object = SKShapeNode(rectOf: CGSize(width: holdWidth, height: objectSize * 0.8), cornerRadius: objectSize/6)
            object.name = "holdObject"
            
            let holdPattern = createHorizontalHoldPattern(width: holdWidth, height: objectSize * 0.8)
            holdPattern.zPosition = -1
            object.addChild(holdPattern)
            
            let holdIcon = createHoldIcon()
            holdIcon.position = CGPoint(x: -holdWidth/4, y: 0)
            object.addChild(holdIcon)
            
        case .pause:
            return
        }
        
        object.fillColor = .clear
        object.strokeColor = .clear
        
        if let image = UIImage(named: "Artboard \(artboardNumber)") {
            let texture = SKTexture(image: image)
            let sprite = SKSpriteNode(texture: texture)
            let spriteSize: CGFloat
            switch type {
            case .tap:
                spriteSize = objectSize
            default:
                spriteSize = objectSize * 0.8
            }
            sprite.size = CGSize(width: spriteSize, height: spriteSize)
            sprite.position = CGPoint.zero
            sprite.zPosition = 2
            sprite.name = "objectSprite"
            object.addChild(sprite)
        } else {
            let texture = SKTexture(imageNamed: "Artboard\(artboardNumber)")
            let sprite = SKSpriteNode(texture: texture)
            let spriteSize: CGFloat
            switch type {
            case .tap:
                spriteSize = objectSize
            default:
                spriteSize = objectSize * 0.8
            }
            sprite.size = CGSize(width: spriteSize, height: spriteSize)
            sprite.position = CGPoint.zero
            sprite.zPosition = 2
            sprite.name = "objectSprite"
            object.addChild(sprite)
        }
        
        object.position = CGPoint(x: spawnX, y: size.height - 150)
        object.zPosition = 10
        
        if intensity > 0.8 {
            switch type {
            case .hold(_):
                break
            default:
                let energyPulse = SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.scale(to: 1.06, duration: 0.5),
                        SKAction.scale(to: 1.0, duration: 0.5)
                    ])
                )
                object.run(energyPulse, withKey: "energyPulse")
            }
        }
        
        object.alpha = 0
        object.setScale(0.8)
        let appearAction = SKAction.group([
            SKAction.fadeIn(withDuration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        object.run(appearAction)
        
        gameObjects.append(object)
        addChild(object)
    }
    
    private func createHorizontalHoldPattern(width: CGFloat, height: CGFloat) -> SKNode {
        let container = SKNode()
        
        for i in 0..<3 {
            let line = SKShapeNode(rectOf: CGSize(width: max(20, width - 8), height: 1), cornerRadius: 0.5)
            line.fillColor = .white
            line.alpha = 0.4
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: CGFloat(i - 1) * 5)
            line.name = "holdLine\(i)"
            
            let flowAction = SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.8, duration: 0.6),
                    SKAction.fadeAlpha(to: 0.2, duration: 0.6)
                ])
            )
            line.run(flowAction, withKey: "holdFlow\(i)")
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
    
    private func updateFallingObjects() {
        let speedMultiplier = selectedLevel?.multiplier ?? 1.0
        let normalizedSpeed = speedMultiplier <= 1.0 ? 1.0 : (1.0 + (speedMultiplier - 1.0) * 0.6)
        let baseSpeed = 52.0
        for object in gameObjects {
            object.position.x -= CGFloat(gameSpeed * baseSpeed / 60 * normalizedSpeed)
        }
    }
    
    private func endGameWithResult(won: Bool) {
        guard !gameEnded else { return }
        gameEnded = true
        
        audioPlayer?.stop()
        
        let finalScore = Int(Double(score) * (selectedLevel?.multiplier ?? 1.0))
        GameDataManager.shared.saveHighScore(finalScore)
        gameKitManager?.submitScore(finalScore)
        
        if finalScore > 1000 {
            gameKitManager?.unlockAchievement("first_thousand")
        }
        if finalScore > 5000 {
            gameKitManager?.unlockAchievement("five_thousand_master")
        }
        
        if won {
            showWinScreen(finalScore: finalScore)
        } else {
            showLoseScreen(finalScore: finalScore)
        }
    }
    
    private func showWinScreen(finalScore: Int) {
        let winLabel = SKLabelNode(text: "YOU WIN!")
        winLabel.fontName = "Arial-Bold"
        winLabel.fontSize = 36
        winLabel.fontColor = .green
        winLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        addChild(winLabel)
        
        let finalScoreLabel = SKLabelNode(text: "Final Score: \(finalScore)")
        finalScoreLabel.fontName = "Arial-Bold"
        finalScoreLabel.fontSize = 24
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(finalScoreLabel)
        
        let accuracy = totalNotes > 0 ? Double(hitNotes) / Double(totalNotes) * 100 : 0
        let accuracyLabel = SKLabelNode(text: "Accuracy: \(Int(accuracy))%")
        accuracyLabel.fontName = "Arial-Bold"
        accuracyLabel.fontSize = 20
        accuracyLabel.fontColor = .gray
        accuracyLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40)
        addChild(accuracyLabel)
        
        for i in 0..<20 {
            let firework = SKShapeNode(circleOfRadius: 5)
            firework.fillColor = colors[randomSource.nextInt(upperBound: colors.count)]
            firework.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(firework)
            
            let angle = CGFloat(i) * CGFloat.pi / 10
            let distance: CGFloat = 200
            let targetPosition = CGPoint(
                x: size.width / 2 + cos(angle) * distance,
                y: size.height / 2 + sin(angle) * distance
            )
            
            let moveAction = SKAction.move(to: targetPosition, duration: 1.0)
            let fadeOut = SKAction.fadeOut(withDuration: 1.0)
            firework.run(SKAction.sequence([
                SKAction.group([moveAction, fadeOut]),
                SKAction.removeFromParent()
            ]))
        }
        
        gameStateMachine?.returnToMenu()
    }
    
    private func showLoseScreen(finalScore: Int) {
        let loseLabel = SKLabelNode(text: "GAME OVER")
        loseLabel.fontName = "Arial-Bold"
        loseLabel.fontSize = 36
        loseLabel.fontColor = .red
        loseLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        addChild(loseLabel)
        
        let reasonLabel = SKLabelNode(text: health <= 0 ? "Health Depleted!" : "Song Failed!")
        reasonLabel.fontName = "Arial-Bold"
        reasonLabel.fontSize = 20
        reasonLabel.fontColor = .orange
        reasonLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        addChild(reasonLabel)
        
        let finalScoreLabel = SKLabelNode(text: "Final Score: \(finalScore)")
        finalScoreLabel.fontName = "Arial-Bold"
        finalScoreLabel.fontSize = 24
        finalScoreLabel.fontColor = .gray
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 30)
        addChild(finalScoreLabel)
        
        gameStateMachine?.returnToMenu()
    }
    
    private func removeOffscreenObjects() {
        gameObjects.removeAll { object in
            if object.position.x < -150 {
                if object == currentHoldObject {
                    currentHoldObject = nil
                    isHolding = false
                    targetZone.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
                    targetZone.lineWidth = 2
                }
                object.removeAllActions()
                object.removeFromParent()
                missNote()
                return true
            }
            return false
        }
    }
    
    private func missNote() {
        updateScore(-1)
        updateHealth(-10)
        consecutiveMisses += 1
        
        if consecutiveMisses >= 5 {
            updateHealth(-20)
            consecutiveMisses = 0
        }
    }
    
    private func hitNote() {
        hitNotes += 1
        consecutiveMisses = 0
        updateScore(10)
        updateHealth(2)
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
        guard !gameObjects.isEmpty else { return }
        
        let targetZoneFrame = targetZone.frame
        let tolerance: CGFloat = 30.0
        let expandedFrame = targetZoneFrame.insetBy(dx: -tolerance, dy: -tolerance)
        
        for (index, object) in gameObjects.enumerated().reversed() {
            guard index < gameObjects.count else { continue }
            
            let objectFrame = object.frame
            
            if expandedFrame.intersects(objectFrame) {
                if object.name == "holdObject" && !isHolding {
                    startHold(object: object, index: index)
                    return
                } else if object.name == "tapObject" {
                    createHitEffect(at: object.position)
                    object.removeFromParent()
                    if index < gameObjects.count {
                        gameObjects.remove(at: index)
                    }
                    hitNote()
                    return
                }
            }
        }
        
        updateScore(-5)
        updateHealth(-5)
        createMissEffect(at: location)
    }
    
    private func startHold(object: SKShapeNode, index: Int) {
        guard !isHolding else { return }
        
        isHolding = true
        holdStartTime = CACurrentMediaTime()
        currentHoldObject = object
        
        object.removeAction(forKey: "energyPulse")
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
                SKAction.scale(to: 1.2, duration: 0.4),
                SKAction.scale(to: 1.0, duration: 0.4)
            ])
        )
        holdIndicator.run(pulseAction, withKey: "holdPulse")
        
        targetZone.strokeColor = .cyan
        targetZone.lineWidth = 6
        
        createHoldStartEffect(at: object.position)
    }
    
    private func endHold() {
        guard let holdObject = currentHoldObject, isHolding else { return }
        guard gameObjects.contains(holdObject) else {
            isHolding = false
            currentHoldObject = nil
            targetZone.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
            targetZone.lineWidth = 2
            return
        }
        
        let holdDuration = CACurrentMediaTime() - holdStartTime
        let requiredDuration: Double = 1.2
        
        holdObject.removeAllActions()
        holdObject.enumerateChildNodes(withName: "holdIndicator") { node, _ in
            node.removeAllActions()
        }
        
        if holdDuration >= requiredDuration * 0.75 {
            updateScore(20)
            updateHealth(5)
            hitNote()
            createHoldSuccessEffect(at: holdObject.position)
        } else {
            updateScore(-10)
            updateHealth(-10)
            createHoldFailEffect(at: holdObject.position)
        }
        
        holdObject.removeFromParent()
        if let index = gameObjects.firstIndex(of: holdObject) {
            gameObjects.remove(at: index)
        }
        
        isHolding = false
        currentHoldObject = nil
        
        targetZone.strokeColor = SKColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 1.0)
        targetZone.lineWidth = 2
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
    
    private func updateHealth(_ points: Int) {
        health = max(0, min(100, health + points))
        healthLabel.text = "HP: \(health)"
        
        if health < 30 {
            healthLabel.fontColor = .red
        } else if health < 60 {
            healthLabel.fontColor = .orange
        } else {
            healthLabel.fontColor = .green
        }
    }
}

struct DDRGameView: View {
    @ObservedObject var stateMachine: GameStateMachine
    @ObservedObject var gameKitManager: GameKitManager
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
        scene.selectedLevel = stateMachine.selectedLevel
        scene.selectedMusic = stateMachine.selectedMusic
        scene.gameStateMachine = stateMachine
        scene.gameKitManager = gameKitManager
        return scene
    }
}

struct SimpleButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .padding(.vertical, 15)
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(8)
        }
    }
}

struct SimpleMusicCard: View {
    let music: MusicData
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(music.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text("BPM: \(Int(music.bpm))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(Int(music.duration/60)):\(String(format: "%02d", Int(music.duration) % 60))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("• \(music.difficulty)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text("▶")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
            )
        }
    }
}

struct SimpleLevelCard: View {
    let level: LevelData
    let isUnlocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(level.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(isUnlocked ? .white : .gray)
                    
                    Text(level.description)
                        .font(.callout)
                        .foregroundColor(isUnlocked ? .gray : .gray.opacity(0.6))
                    
                    Text("Multiplier: \(level.multiplier, specifier: "%.1f")x")
                        .font(.caption)
                        .foregroundColor(isUnlocked ? .white : .gray)
                }
                
                Spacer()
                
                if !isUnlocked {
                    Text("🔒")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(isUnlocked ? 0.2 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(isUnlocked ? 0.4 : 0.2), lineWidth: 1)
                    )
            )
        }
        .disabled(!isUnlocked)
    }
}

struct ContentView: View {
    @StateObject private var stateMachine = GameStateMachine()
    @StateObject private var gameKitManager = GameKitManager()
    
    var body: some View {
        NavigationView {
            Group {
                switch stateMachine.currentState {
                case .mainMenu:
                    MainMenuView(stateMachine: stateMachine, gameKitManager: gameKitManager)
                case .levelSelection:
                    LevelSelectionView(stateMachine: stateMachine)
                case .musicSelection:
                    MusicSelectionView(stateMachine: stateMachine)
                case .playing:
                    DDRGameView(stateMachine: stateMachine, gameKitManager: gameKitManager)
                case .gameOver:
                    GameOverView(stateMachine: stateMachine)
                case .settings:
                    SettingsView(stateMachine: stateMachine, gameKitManager: gameKitManager)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MainMenuView: View {
    @ObservedObject var stateMachine: GameStateMachine
    @ObservedObject var gameKitManager: GameKitManager
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 15) {
                    Text("RHYTHM STRIKE")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Face Tracking Rhythm Game")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 20) {
                    Text("High Score: \(GameDataManager.shared.getHighScore())")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    if gameKitManager.isAuthenticated {
                        Text("Welcome, \(gameKitManager.localPlayer?.displayName ?? "Player")!")
                            .font(.callout)
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(spacing: 15) {
                    SimpleButton(title: "START GAME") {
                        stateMachine.transition(to: .levelSelection)
                    }
                    
                    SimpleButton(title: "SETTINGS") {
                        stateMachine.transition(to: .settings)
                    }
                }
                
                Spacer()
                
                Text("Tap objects when they reach the target zone!")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 40)
        }
    }
}

struct LevelSelectionView: View {
    @ObservedObject var stateMachine: GameStateMachine
    let levels = GameDataManager.shared.availableLevels
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button("← Back") {
                        stateMachine.transition(to: .mainMenu)
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    
                    Spacer()
                    
                    Text("SELECT LEVEL")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                VStack(spacing: 20) {
                    ForEach(levels, id: \.id) { level in
                        SimpleLevelCard(
                            level: level,
                            isUnlocked: GameDataManager.shared.isLevelUnlocked(level)
                        ) {
                            if GameDataManager.shared.isLevelUnlocked(level) {
                                stateMachine.selectLevel(level)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
    }
}

struct MusicSelectionView: View {
    @ObservedObject var stateMachine: GameStateMachine
    let musicList = GameDataManager.shared.availableMusic
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Button("← Back") {
                        stateMachine.transition(to: .levelSelection)
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    
                    Spacer()
                    
                    Text("SELECT MUSIC")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                if let selectedLevel = stateMachine.selectedLevel {
                    Text("Level: \(selectedLevel.name)")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(musicList.indices, id: \.self) { index in
                            SimpleMusicCard(music: musicList[index]) {
                                stateMachine.selectMusic(musicList[index])
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
            }
        }
    }
}

struct GameOverView: View {
    @ObservedObject var stateMachine: GameStateMachine
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("GAME OVER")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("High Score: \(GameDataManager.shared.getHighScore())")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                VStack(spacing: 20) {
                    SimpleButton(title: "PLAY AGAIN") {
                        stateMachine.transition(to: .playing)
                    }
                    
                    SimpleButton(title: "CHANGE MUSIC") {
                        stateMachine.transition(to: .musicSelection)
                    }
                    
                    SimpleButton(title: "MAIN MENU") {
                        stateMachine.returnToMenu()
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var stateMachine: GameStateMachine
    @ObservedObject var gameKitManager: GameKitManager
    @State private var soundEnabled = true
    @State private var vibrationEnabled = true
    @State private var difficulty = 1.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Button("← Back") {
                        stateMachine.transition(to: .mainMenu)
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    
                    Spacer()
                    
                    Text("SETTINGS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        SimpleSettingRow(title: "Sound Effects", isOn: $soundEnabled)
                        SimpleSettingRow(title: "Vibration", isOn: $vibrationEnabled)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Global Difficulty")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("Easy")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Slider(value: $difficulty, in: 0.5...2.0, step: 0.1)
                                    .accentColor(.white)
                                
                                Text("Hard")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Text("Multiplier: \(difficulty, specifier: "%.1f")x")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                )
                        )
                        
                        Button("Reset High Score") {
                            UserDefaults.standard.set(0, forKey: "highScore")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 30)
                }
            }
        }
    }
}

struct SimpleSettingRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .white))
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct DDRGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#Preview {
    ContentView()
}
