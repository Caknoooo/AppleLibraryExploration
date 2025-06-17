import SwiftUI
import AVFoundation

class SimpleBeatDetector: ObservableObject {
    @Published var isPlaying = false
    @Published var currentBeat = 0
    @Published var bpm: Float = 0.0
    @Published var beatStrength: Float = 0.0
    @Published var currentFaceLabel = 0
    @Published var targetFaceLabel = 0
    @Published var timeUntilNextChange: Float = 0.0
    @Published var score = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var faceTimer: Timer?
    private var beatTimer: Timer?
    private var startTime: Date?
    private var lastFaceChangeTime: Date?
    private let faceChangeDuration: TimeInterval = 4.0
    private var beatCounter = 0
    private var currentBPMTarget: Float = 120.0
    private var beatInterval: TimeInterval = 0.5
    
    let faceLabels = [
        "Neutral", "Happy", "Sad", "Angry", "Surprised", "Fearful", "Disgusted",
        "Smile", "Frown", "Wink Left", "Wink Right", "Eyebrows Up", "Eyebrows Down",
        "Mouth Open", "Mouth Closed", "Tongue Out", "Kiss", "Cheek Puff", "Eye Squint",
        "Head Tilt Left", "Head Tilt Right", "Look Up", "Look Down", "Look Left", "Look Right",
        "Jaw Drop", "Confused"
    ]
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func loadAudioFile(named fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("Audio file not found: \(fileName).mp3")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            print("Audio file loaded successfully: \(fileName)")
        } catch {
            print("Failed to load audio file: \(error)")
        }
    }
    
    func startPlayback() {
        guard let player = audioPlayer else {
            loadAudioFile(named: "attention")
            guard let loadedPlayer = audioPlayer else {
                print("No audio file loaded")
                return
            }
            loadedPlayer.play()
            isPlaying = true
            startTime = Date()
            lastFaceChangeTime = Date()
            beatCounter = 0
            currentBPMTarget = Float.random(in: 100...160)
            beatInterval = 60.0 / Double(currentBPMTarget)
            generateNextTargetFace()
            startTimers()
            return
        }
        
        player.play()
        isPlaying = true
        startTime = Date()
        lastFaceChangeTime = Date()
        beatCounter = 0
        currentBPMTarget = Float.random(in: 100...160)
        beatInterval = 60.0 / Double(currentBPMTarget)
        generateNextTargetFace()
        startTimers()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        stopTimers()
        resetValues()
    }
    
    private func startTimers() {
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { _ in
            self.simulateBeat()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateCountdown()
            self.changeBPMOccasionally()
        }
    }
    
    private func stopTimers() {
        timer?.invalidate()
        faceTimer?.invalidate()
        beatTimer?.invalidate()
        timer = nil
        faceTimer = nil
        beatTimer = nil
    }
    
    private func resetValues() {
        currentBeat = 0
        beatStrength = 0.0
        bpm = 0.0
        currentFaceLabel = 0
        targetFaceLabel = 0
        timeUntilNextChange = 0.0
        score = 0
        beatCounter = 0
        lastFaceChangeTime = nil
    }
    
    private func simulateBeat() {
        let randomBeat = Float.random(in: 0.3...1.0)
        
        DispatchQueue.main.async {
            self.beatStrength = randomBeat
            self.currentBeat += 1
            self.bpm = self.currentBPMTarget + Float.random(in: -5...5)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.beatStrength = self.beatStrength * 0.5
        }
    }
    
    private func changeBPMOccasionally() {
        if Int.random(in: 1...200) == 1 {
            let newBPM = Float.random(in: 100...160)
            currentBPMTarget = newBPM
            beatInterval = 60.0 / Double(newBPM)
            
            beatTimer?.invalidate()
            beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { _ in
                self.simulateBeat()
            }
        }
    }
    
    private func updateCountdown() {
        guard let lastChange = lastFaceChangeTime else { return }
        
        let elapsed = Date().timeIntervalSince(lastChange)
        let remaining = faceChangeDuration - elapsed
        
        DispatchQueue.main.async {
            self.timeUntilNextChange = Float(max(0, remaining))
            
            if remaining <= 0 {
                self.checkScoreAndChangeFace()
            }
        }
    }
    
    private func generateNextTargetFace() {
        let faceIndex = beatCounter % 27
        targetFaceLabel = faceIndex
        lastFaceChangeTime = Date()
    }
    
    private func checkScoreAndChangeFace() {
        if checkFaceMatch() {
            score += 100
        }
        
        beatCounter += 1
        generateNextTargetFace()
    }
    
    func getCurrentFaceName() -> String {
        return faceLabels[currentFaceLabel]
    }
    
    func getTargetFaceName() -> String {
        return faceLabels[targetFaceLabel]
    }
    
    func checkFaceMatch() -> Bool {
        return currentFaceLabel == targetFaceLabel
    }
    
    func updateCurrentFace(to labelIndex: Int) {
        guard labelIndex >= 0 && labelIndex < 27 else { return }
        currentFaceLabel = labelIndex
    }
}

struct ContentView: View {
    @StateObject private var beatDetector = SimpleBeatDetector()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.purple, .blue, .black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Beat Detector")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                BeatVisualizerView(
                    beatStrength: beatDetector.beatStrength,
                    isPlaying: beatDetector.isPlaying
                )
                
                VStack(spacing: 15) {
                    HStack(spacing: 40) {
                        StatView(title: "BPM", value: String(format: "%.1f", beatDetector.bpm))
                        StatView(title: "Score", value: "\(beatDetector.score)")
                    }
                    
                    if beatDetector.isPlaying {
                        VStack {
                            Text("Next Change In")
                                .foregroundColor(.white)
                                .font(.caption)
                            Text(String(format: "%.1fs", beatDetector.timeUntilNextChange))
                                .foregroundColor(.yellow)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    
                    VStack(spacing: 10) {
                        Text("Face Challenge")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("Target")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(beatDetector.getTargetFaceName())
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .frame(height: 35)
                            }
                            .frame(width: 100)
                            
                            VStack {
                                Text("Current")
                                    .foregroundColor(.cyan)
                                    .font(.caption)
                                Text(beatDetector.getCurrentFaceName())
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                    .frame(height: 35)
                            }
                            .frame(width: 100)
                        }
                        
                        HStack {
                            Circle()
                                .fill(beatDetector.checkFaceMatch() ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(beatDetector.checkFaceMatch() ? "MATCH! +100" : "No Match")
                                .foregroundColor(beatDetector.checkFaceMatch() ? .green : .red)
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    VStack {
                        Text("Beat Strength")
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        ProgressView(value: beatDetector.beatStrength)
                            .progressViewStyle(LinearProgressViewStyle())
                            .accentColor(.green)
                            .frame(width: 180)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 15) {
                    Button(action: {
                        if beatDetector.isPlaying {
                            beatDetector.stopPlayback()
                        } else {
                            beatDetector.startPlayback()
                        }
                    }) {
                        HStack {
                            Image(systemName: beatDetector.isPlaying ? "stop.fill" : "play.fill")
                            Text(beatDetector.isPlaying ? "Stop" : "Play")
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 120, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(beatDetector.isPlaying ? Color.red : Color.green)
                        )
                    }
                    
                    if beatDetector.isPlaying {
                        VStack {
                            Text("Demo: Tap to change face")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                                Button("😐") { beatDetector.updateCurrentFace(to: 0) }
                                Button("😊") { beatDetector.updateCurrentFace(to: 1) }
                                Button("😢") { beatDetector.updateCurrentFace(to: 2) }
                                Button("😠") { beatDetector.updateCurrentFace(to: 3) }
                                Button("😲") { beatDetector.updateCurrentFace(to: 4) }
                                Button("😱") { beatDetector.updateCurrentFace(to: 5) }
                                Button("🤢") { beatDetector.updateCurrentFace(to: 6) }
                                Button("🙂") { beatDetector.updateCurrentFace(to: 7) }
                                Button("🙁") { beatDetector.updateCurrentFace(to: 8) }
                                Button("😉") { beatDetector.updateCurrentFace(to: 9) }
                            }
                            .foregroundColor(.white)
                            .font(.title3)
                        }
                    }
                    
                    Text("Add 'sample_music.mp3' to your bundle")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }
}

struct BeatVisualizerView: View {
    let beatStrength: Float
    let isPlaying: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 150, height: 150)
            
            Circle()
                .stroke(Color.cyan, lineWidth: 6)
                .frame(width: 150, height: 150)
                .scaleEffect(1.0 + CGFloat(beatStrength) * 0.4)
                .opacity(Double(beatStrength))
                .animation(.easeOut(duration: 0.1), value: beatStrength)
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.cyan, .blue]),
                        center: .center,
                        startRadius: 8,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(1.0 + CGFloat(beatStrength) * 0.2)
                .animation(.easeOut(duration: 0.1), value: beatStrength)
            
            Image(systemName: isPlaying ? "waveform" : "music.note")
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 70)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
