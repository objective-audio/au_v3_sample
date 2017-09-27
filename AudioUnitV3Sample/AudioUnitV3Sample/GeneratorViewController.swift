//
//  ViewController.swift
//  AudioUnitV3Sample
//
//  Created by 八十嶋祐樹 on 2015/11/23.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import UIKit
import AVFoundation

class GeneratorViewController: UIViewController {
    var audioEngine: AVAudioEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupGeneratorAudioUnit()
    }
    
    func setupGeneratorAudioUnit() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            print(error)
            return
        }
        
        // エンジンの生成
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        AudioUnitGeneratorSample.registerSubclassOnce
        
        // AVAudioUnitをインスタンス化する。生成処理が終わるとcompletionHandlerが呼ばれる
        AVAudioUnit.instantiate(with: AudioUnitGeneratorSample.audioComponentDescription, options: AudioComponentInstantiationOptions(rawValue: 0)) { (audioUnitNode: AVAudioUnit?, err: Error?) -> Void in
            guard let audioUnitNode = audioUnitNode else {
                if let err = err {
                    print(err)
                }
                return
            }
            
            // Generatorの処理。サイン波を鳴らす
            let generatorUnit = audioUnitNode.auAudioUnit as! AudioUnitGeneratorSample
            
            var phase: Float64 = 0.0
            
            generatorUnit.kernelRenderBlock = { buffer in
                // このブロックの中はオーディオのスレッドから呼ばれる
                let format = buffer.format
                let currentPhase: Float64 = phase
                let phasePerFrame: Float64 = 1000.0 / format.sampleRate * 2.0 * Double.pi;
                for ch in 0..<format.channelCount {
                    if let channelData = buffer.floatChannelData {
                        phase = fillSine(channelData[Int(ch)], length: buffer.frameLength, startPhase: currentPhase, phasePerFrame: phasePerFrame)
                    }
                }
            }
            
            // ノードを追加
            engine.attach(audioUnitNode)
            
            let sampleRate: Double = AVAudioSession.sharedInstance().sampleRate
            let format: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
            
            // 接続
            engine.connect(audioUnitNode, to: engine.mainMixerNode, format: format)
            
            do {
                // スタート
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            } catch {
                print(error)
                return
            }
        }
    }
}

