//
//  AudioUnitGeneratorSample.swift
//  AudioUnitV3Sample
//
//  Created by 八十嶋祐樹 on 2015/11/23.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import AVFoundation

class AudioUnitGeneratorSample: AUAudioUnit {
    
    // MARK: - Private
    
    private let _kernel: AudioUnitSampleKernel = AudioUnitSampleKernel()
    
    private var _outputBusArray: AUAudioUnitBusArray!
    private var _internalRenderBlock: AUInternalRenderBlock!
    
    // MARK: - Global
    
    static let audioComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Generator, // Generatorはアウトが繋がっていればレンダーされる
        componentSubType: hfsTypeCode("gnsp"), // サンプルなので適当
        componentManufacturer: hfsTypeCode("Demo"), // サンプルなので適当
        componentFlags: 0,
        componentFlagsMask: 0
    );
    
    override static func initialize() {
        struct Static { static var token: dispatch_once_t = 0 }
        
        dispatch_once(&Static.token) {
            // In-Process用なので、Extensionの場合は呼んではいけない
            AUAudioUnit.registerSubclass(
                self,
                asComponentDescription: AudioUnitGeneratorSample.audioComponentDescription,
                name: "AudioUnitGeneratorSample",
                version: UINT32_MAX
            )
        }
    }
    
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
            
            // 独自のオーディオ処理をするブロックを呼び出す
            if let renderBlock = kernel.renderBlock.value {
                renderBlock(buffer: buffer)
            }
            
            // アウトのバッファが元からあればそのまま使ってコピーをし、なければこちらのバッファをセットする
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
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
            let bus = try AUAudioUnitBus(format: format)
            self._outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.Output, busses: [bus])
        } catch {
            throw error
        }
    }
    
    override var outputBusses : AUAudioUnitBusArray {
        // 随時呼ばれるので、動的には作らない
        return self._outputBusArray
    }
    
    override var internalRenderBlock: AUInternalRenderBlock {
        // 随時呼ばれるので、動的には作らない
        return self._internalRenderBlock
    }
    
    override func shouldChangeToFormat(format: AVAudioFormat, forBus bus: AUAudioUnitBus) -> Bool {
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
        let bus = self.outputBusses[0]
        _kernel.buffer.value = AVAudioPCMBuffer(PCMFormat: bus.format, frameCapacity: self.maximumFramesToRender)
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
