<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI汉代乐队 - 手势交互</title>
    <script src="https://cdn.jsdelivr.net/npm/@mediapipe/hands/hands.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/tone@14.7.77/build/Tone.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: "SimSun", "STSong", serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #d4af37;
            overflow: hidden;
            height: 100vh;
        }
        #container {
            display: flex;
            height: 100vh;
        }
        #video-container {
            flex: 1;
            position: relative;
            background: #0f0f1e;
        }
        video, canvas {
            position: absolute;
            width: 100%;
            height: 100%;
            object-fit: cover;
            transform: scaleX(-1);
        }
        #info-panel {
            width: 350px;
            padding: 20px;
            background: rgba(26, 26, 46, 0.95);
            border-left: 3px solid #d4af37;
            overflow-y: auto;
        }
        h1 {
            font-size: 24px;
            text-align: center;
            margin-bottom: 10px;
            text-shadow: 0 0 10px #d4af37;
        }
        .subtitle {
            text-align: center;
            font-size: 14px;
            color: #888;
            margin-bottom: 20px;
        }
        .gesture-guide {
            background: rgba(212, 175, 55, 0.1);
            border: 1px solid #d4af37;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
        }
        .gesture-item {
            display: flex;
            align-items: center;
            margin: 10px 0;
            padding: 8px;
            background: rgba(0,0,0,0.3);
            border-radius: 5px;
            transition: all 0.3s;
        }
        .gesture-item.active {
            background: rgba(212, 175, 55, 0.3);
            transform: scale(1.05);
            box-shadow: 0 0 15px rgba(212, 175, 55, 0.5);
        }
        .gesture-icon {
            font-size: 24px;
            margin-right: 10px;
        }
        #status {
            text-align: center;
            font-size: 18px;
            margin: 20px 0;
            padding: 10px;
            background: rgba(0,0,0,0.5);
            border-radius: 5px;
            min-height: 50px;
        }
        .instrument-status {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-top: 20px;
        }
        .instrument {
            text-align: center;
            padding: 10px;
            background: rgba(0,0,0,0.3);
            border-radius: 5px;
            border: 1px solid #333;
        }
        .instrument.playing {
            border-color: #d4af37;
            background: rgba(212, 175, 55, 0.2);
            animation: pulse 0.5s;
        }
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
        }
        #start-btn {
            width: 100%;
            padding: 15px;
            font-size: 18px;
            background: linear-gradient(135deg, #d4af37, #b8941f);
            color: #1a1a2e;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
            margin-top: 20px;
            transition: all 0.3s;
        }
        #start-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(212, 175, 55, 0.4);
        }
        .han-pattern {
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            height: 100px;
            background: url("data:image/svg+xml,%3Csvg width='100' height='100' viewBox='0 0 100 100' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M0 50 Q25 30 50 50 T100 50' fill='none' stroke='%23d4af37' stroke-width='2' opacity='0.3'/%3E%3C/svg%3E");
            pointer-events: none;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="video-container">
            <video id="video" playsinline></video>
            <canvas id="canvas"></canvas>
            <div class="han-pattern"></div>
        </div>
        
        <div id="info-panel">
            <h1>🎵 AI汉代乐队</h1>
            <div class="subtitle">手势交互 · 千年之音</div>
            
            <div class="gesture-guide">
                <h3>手势指令</h3>
                <div class="gesture-item" id="g-open">
                    <span class="gesture-icon">🖐️</span>
                    <span>张开手掌 → 编钟</span>
                </div>
                <div class="gesture-item" id="g-fist">
                    <span class="gesture-icon">✊</span>
                    <span>握拳 → 建鼓</span>
                </div>
                <div class="gesture-item" id="g-point">
                    <span class="gesture-icon">☝️</span>
                    <span>食指指天 → 笛声</span>
                </div>
                <div class="gesture-item" id="g-wave">
                    <span class="gesture-icon">👋</span>
                    <span>挥手 → 琴弦</span>
                </div>
            </div>
            
            <div id="status">点击开始，召唤汉代乐队</div>
            
            <div class="instrument-status">
                <div class="instrument" id="inst-bell">🔔 编钟</div>
                <div class="instrument" id="inst-drum">🥁 建鼓</div>
                <div class="instrument" id="inst-flute">🎋 笛</div>
                <div class="instrument" id="inst-qin">🎻 琴</div>
            </div>
            
            <button id="start-btn">🎭 开始演奏</button>
        </div>
    </div>

    <script>
        // 音频系统
        let synth, bellSynth, drumSynth, fluteSynth, qinSynth;
        let isPlaying = false;
        let currentGesture = null;
        let lastPlayTime = 0;
        
        // 五声音阶（宫商角徵羽）
        const pentatonic = ["C4", "D4", "E4", "G4", "A4"];
        const pentatonicLow = ["C3", "D3", "E3", "G3", "A3"];
        
        // 初始化音频
        async function initAudio() {
            await Tone.start();
            
            // 编钟音色
            bellSynth = new Tone.PolySynth(Tone.FMSynth, {
                harmonicity: 8.5,
                modulationIndex: 10,
                oscillator: { type: "sine" },
                modulation: { type: "sine" },
                modulationEnvelope: {
                    attack: 0.01,
                    decay: 2,
                    sustain: 0.01,
                    release: 3
                },
                envelope: {
                    attack: 0.01,
                    decay: 1.5,
                    sustain: 0.01,
                    release: 2
                }
            }).toDestination();
            
            // 鼓声
            drumSynth = new Tone.MembraneSynth({
                pitchDecay: 0.05,
                octaves: 10,
                oscillator: { type: "sine" },
                envelope: {
                    attack: 0.001,
                    decay: 0.4,
                    sustain: 0.01,
                    release: 1.4,
                    attackCurve: "exponential"
                }
            }).toDestination();
            
            // 笛声
            fluteSynth = new Tone.Synth({
                oscillator: { type: "triangle" },
                envelope: {
                    attackTime: 0.1,
                    decayTime: 0.2,
                    sustain: 0.5,
                    releaseTime: 0.8,
                }
            }).toDestination();
            
            // 琴声
            qinSynth = new Tone.PluckSynth({
                attackNoise: 1,
                dampening: 4000,
                resonance: 0.7
            }).toDestination();
            
            // 添加混响
            const reverb = new Tone.Reverb({
                decay: 8,
                wet: 0.3
            }).toDestination();
            
            bellSynth.connect(reverb);
            fluteSynth.connect(reverb);
            qinSynth.connect(reverb);
        }
        
        // 播放乐器
        function playInstrument(type) {
            const now = Date.now();
            if (now - lastPlayTime < 200) return; // 防抖
            lastPlayTime = now;
            
            const note = pentatonic[Math.floor(Math.random() * pentatonic.length)];
            const lowNote = pentatonicLow[Math.floor(Math.random() * pentatonicLow.length)];
            
            switch(type) {
                case 'open': // 编钟
                    bellSynth.triggerAttackRelease(note, "2n");
                    highlightInstrument('inst-bell');
                    break;
                case 'fist': // 鼓
                    drumSynth.triggerAttackRelease("C1", "8n");
                    setTimeout(() => drumSynth.triggerAttackRelease("G1", "8n"), 100);
                    highlightInstrument('inst-drum');
                    break;
                case 'point': // 笛
                    fluteSynth.triggerAttackRelease(note, "4n");
                    setTimeout(() => fluteSynth.triggerAttackRelease(
                        pentatonic[Math.floor(Math.random() * pentatonic.length)], "4n"
                    ), 150);
                    highlightInstrument('inst-flute');
                    break;
                case 'wave': // 琴
                    qinSynth.triggerAttackRelease(lowNote, "8n");
                    highlightInstrument('inst-qin');
                    break;
            }
        }
        
        function highlightInstrument(id) {
            const el = document.getElementById(id);
            el.classList.add('playing');
            setTimeout(() => el.classList.remove('playing'), 500);
        }
        
        // MediaPipe Hands 设置
        const videoElement = document.getElementById('video');
        const canvasElement = document.getElementById('canvas');
        const canvasCtx = canvasElement.getContext('2d');
        
        function onResults(results) {
            canvasElement.width = videoElement.videoWidth;
            canvasElement.height = videoElement.videoHeight;
            
            canvasCtx.save();
            canvasCtx.clearRect(0, 0, canvasElement.width, canvasElement.height);
            canvasCtx.drawImage(results.image, 0, 0, canvasElement.width, canvasElement.height);
            
            if (results.multiHandLandmarks && results.multiHandLandmarks.length > 0) {
                const landmarks = results.multiHandLandmarks[0];
                
                // 绘制手部骨架
                drawConnectors(canvasCtx, landmarks, HAND_CONNECTIONS, 
                    {color: '#d4af37', lineWidth: 3});
                drawLandmarks(canvasCtx, landmarks, 
                    {color: '#ff6b6b', lineWidth: 1, radius: 3});
                
                // 手势识别
                const gesture = recognizeGesture(landmarks);
                if (gesture !== currentGesture) {
                    currentGesture = gesture;
                    updateGestureUI(gesture);
                }
                if (gesture && isPlaying) {
                    playInstrument(gesture);
                }
            }
            
            canvasCtx.restore();
        }
        
        // 简单手势识别逻辑
        function recognizeGesture(landmarks) {
            const thumb = landmarks[4];
            const index = landmarks[8];
            const middle = landmarks[12];
            const ring = landmarks[16];
            const pinky = landmarks[20];
            const wrist = landmarks[0];
            
            // 计算手指伸直程度
            const fingers = [index, middle, ring, pinky];
            const extendedFingers = fingers.filter(f => 
                f.y < landmarks[0].y - 0.1 || Math.hypot(f.x - wrist.x, f.y - wrist.y) > 0.15
            ).length;
            
            // 识别逻辑
            if (extendedFingers >= 4) return 'open';      // 张开手掌
            if (extendedFingers <= 1) return 'fist';      // 握拳
            if (extendedFingers === 1 && index.y < middle.y) return 'point'; // 食指指天
            if (extendedFingers === 2) return 'wave';     // 挥手（简化）
            
            return null;
        }
        
        function updateGestureUI(gesture) {
            // 重置所有手势
            document.querySelectorAll('.gesture-item').forEach(el => 
                el.classList.remove('active'));
            
            const statusEl = document.getElementById('status');
            const gestureNames = {
                'open': '🖐️ 编钟响起，金石之声',
                'fist': '✊ 建鼓动，雷霆万钧',
                'point': '☝️ 笛声悠扬，穿云裂石',
                'wave': '👋 琴弦拨动，余音绕梁'
            };
            
            if (gesture) {
                document.getElementById('g-' + gesture).classList.add('active');
                statusEl.textContent = gestureNames[gesture];
            } else {
                statusEl.textContent = '做出手势，演奏古乐';
            }
        }
        
        // 启动按钮
        document.getElementById('start-btn').addEventListener('click', async () => {
            if (!isPlaying) {
                await initAudio();
                
                const hands = new Hands({
                    locateFile: (file) => {
                        return `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`;
                    }
                });
                
                hands.setOptions({
                    maxNumHands: 1,
                    modelComplexity: 1,
                    minDetectionConfidence: 0.5,
                    minTrackingConfidence: 0.5
                });
                
                hands.onResults(onResults);
                
                const camera = new Camera(videoElement, {
                    onFrame: async () => {
                        await hands.send({image: videoElement});
                    },
                    width: 640,
                    height: 480
                });
                
                camera.start();
                
                isPlaying = true;
                document.getElementById('start-btn').textContent = '🎭 演奏中...';
                document.getElementById('status').textContent = '请做出手势';
            }
        });
    </script>
</body>
</html>
