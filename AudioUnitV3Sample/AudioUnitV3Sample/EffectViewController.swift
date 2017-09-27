//
//  EffectViewController.swift
//  AudioUnitV3Sample
//
//  Created by 八十嶋祐樹 on 2015/11/29.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

class EffectViewController: UIViewController {
    @IBOutlet weak var slider: UISlider!
    
    var audioEngine: AVAudioEngine?
    var delayLevel = Atomic<Float>(val: 0.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupEffectAudioUnit()
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        delayLevel.value = sender.value
    }
    
    func setupEffectAudioUnit() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch {
            print(error)
            return
        }
        
        // エンジンの生成
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let delayLevel = self.delayLevel
        self.slider.value = delayLevel.value
        
        AudioUnitEffectSample.registerSubclassOnce
        
        // AVAudioUnitをインスタンス化する。生成処理が終わるとcompletionHandlerが呼ばれる
        AVAudioUnit.instantiate(with: AudioUnitEffectSample.audioComponentDescription, options: AudioComponentInstantiationOptions(rawValue: 0)) { (audioUnitNode: AVAudioUnit?, err: Error?) in
            guard let audioUnitNode = audioUnitNode else {
                if let err = err {
                    print(err)
                }
                return
            }
            
            // ノードを追加
            engine.attach(audioUnitNode)
            
            let sampleRate = AVAudioSession.sharedInstance().sampleRate
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                abort()
            }
            
            guard let url = Bundle.main.url(forAuxiliaryExecutable: "EffectSampleBeat.m4a") else {
                print("'EffectSampleBeat.m4a' not found.")
                return
            }
            
            let playerNode = AVAudioPlayerNode()
            engine.attach(playerNode)
            
            // 接続
            engine.connect(audioUnitNode, to: engine.mainMixerNode, format: format)
            engine.connect(playerNode, to: audioUnitNode, format: format)
            
            // エフェクトの処理（ディレイ）
            guard let delayBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate) / 2) else {
                abort()
            }
            delayBuffer.frameLength = delayBuffer.frameCapacity
            var delayFrame: AVAudioFrameCount = 0
            
            let effectUnit = audioUnitNode.auAudioUnit as! AudioUnitEffectSample
            
            effectUnit.kernelRenderBlock = { buffer in
                // このブロックの中はオーディオのスレッドから呼ばれる
                let delayLevel = [delayLevel.value]
                let format = buffer.format
                var bufferFrame: AVAudioFrameCount = 0
                
                while bufferFrame < buffer.frameLength {
                    let copyFrame = min(delayBuffer.frameLength - delayFrame, buffer.frameLength - bufferFrame)
                    
                    for ch in 0..<format.channelCount {
                        if let bufferChannelData = buffer.floatChannelData, let delayChannelData = delayBuffer.floatChannelData {
                            let bufferData = bufferChannelData[Int(ch)].advanced(by: Int(bufferFrame))
                            let delayData = delayChannelData[Int(ch)].advanced(by: Int(delayFrame))
                            let copyLength = vDSP_Length(copyFrame)
                            vDSP_vsmul(delayData, 1, delayLevel, delayData, 1, copyLength)
                            vDSP_vswap(bufferData, 1, delayData, 1, copyLength)
                            vDSP_vadd(bufferData, 1, delayData, 1, bufferData, 1, copyLength)
                        }
                    }
                    
                    delayFrame += copyFrame
                    if delayFrame != 0 {
                        delayFrame %= delayBuffer.frameLength
                    }
                    bufferFrame += copyFrame
                }
            }
            
            do {
                let audioFile = try AVAudioFile(forReading: url, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
                playerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
                
                // スタート
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
                
                playerNode.play()
            } catch {
                print(error)
                return
            }
        }
    }
}
