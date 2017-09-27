//
//  AudioUnitEffectSample.swift
//  AudioUnitV3Sample
//
//  Created by 八十嶋祐樹 on 2015/11/29.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import AVFoundation

class AudioUnitEffectSample: AUAudioUnit {
    
    // MARK: - Private
    
    private let _kernel: AudioUnitSampleKernel = AudioUnitSampleKernel()
    
    private var _outputBusArray: AUAudioUnitBusArray!
    private var _inputBusArray: AUAudioUnitBusArray!
    private var _internalRenderBlock: AUInternalRenderBlock!
    
    // MARK: - Global
    
    static let audioComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect, // Effectはインとアウトを両方接続するとレンダーされる
        componentSubType: hfsTypeCode("efsp"), // サンプルなので適当
        componentManufacturer: hfsTypeCode("Demo"), // サンプルなので適当
        componentFlags: 0,
        componentFlagsMask: 0
    );
    
    static let registerSubclassOnce: Void = {
        // In-Process用なので、Extensionの場合は呼んではいけない
        AUAudioUnit.registerSubclass(
            AudioUnitEffectSample.self,
            as: AudioUnitEffectSample.audioComponentDescription,
            name: "AudioUnitEffectSample",
            version: UINT32_MAX
        )
    }()
    
    // MARK: - Override
    
    override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        
        // 初期化
        // internalRenderBlockやoutputBussesで値を返すのに必要なものを作っておく
        
        // オーディオ処理内部で使うオブジェクト
        let kernel = self._kernel
        
        // オーディオ処理をするブロック
        self._internalRenderBlock = { (actionFlags, timeStamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock) in
            // このブロックの中はオーディオのスレッドから呼ばれる
            
            guard let buffer = kernel.buffer.value else {
                return noErr
            }
            
            // 今、処理をするフレーム数をバッファにセット（maximumFramesToRenderより多くはならないはず）
            buffer.frameLength = frameCount
            
            // 入力からオーディオデータを読み込む
            if let pullInputBlock = pullInputBlock {
                let _ = pullInputBlock(actionFlags, timeStamp, frameCount, 0, buffer.mutableAudioBufferList)
            }
            
            // 独自のオーディオ処理をするブロックを呼び出す
            if let renderBlock = kernel.renderBlock.value {
                renderBlock(buffer)
            }
            
            // アウトのバッファが元からあればそのまま使い、なければこちらからセットする
            let out_abl = UnsafeMutableAudioBufferListPointer(outputData)
            let in_abl = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            
            for i in 0..<out_abl.count {
                let out_data = out_abl[i].mData
                let in_data = in_abl[i].mData
                
                if out_data == nil {
                    out_abl[i].mData = in_data
                } else if out_data != in_data {
                    memcpy(out_data, in_data, Int(out_abl[i].mDataByteSize))
                }
            }
            
            return noErr
        }
        
        do {
            try super.init(componentDescription: componentDescription, options: options)
            
            // formatは仮で、必要な数だけバスを作る
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) else {
                abort()
            }
            let outputBus = try AUAudioUnitBus(format: format)
            self._outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus])
            let inputBus = try AUAudioUnitBus(format: format)
            self._inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.input, busses: [inputBus])
            
        } catch {
            throw error
        }
    }
    
    override var outputBusses : AUAudioUnitBusArray {
        // 随時呼ばれるので、動的には作らない
        return self._outputBusArray
    }
    
    override var inputBusses : AUAudioUnitBusArray {
        // 随時呼ばれるので、動的には作らない
        return self._inputBusArray
    }
    
    override var internalRenderBlock: AUInternalRenderBlock {
        // 随時呼ばれるので、動的には作らない
        return self._internalRenderBlock
    }
    
    override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        // バスが接続されると呼ばれる。対応不可能なフォーマットならfalseを返す
        return true
    }
    
    override func allocateRenderResources() throws {
        do {
            // super呼び出し必須
            try super.allocateRenderResources()
        } catch {
            throw error
        }
        
        // バスのフォーマットに応じてKernelにバッファを作成する
        let outputBus = self.outputBusses[0]
        let inputBus = self.inputBusses[0]
        
        if outputBus.format == inputBus.format {
            _kernel.buffer.value = AVAudioPCMBuffer(pcmFormat: outputBus.format, frameCapacity: self.maximumFramesToRender)
        }
    }
    
    override func deallocateRenderResources() {
        // Kernelからバッファを解放
        _kernel.buffer.value = nil
    }
    
    // MARK: - Accessor
    
    var kernelRenderBlock: KernelRenderBlock? {
        get {
            return _kernel.renderBlock.value
        }
        set {
            _kernel.renderBlock.value = newValue
        }
    }
}
