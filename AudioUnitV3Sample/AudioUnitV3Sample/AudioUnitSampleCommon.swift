//
//  AudioUnitSampleCommon.swift
//  AudioUnitV3Sample
//
//  Created by 八十嶋祐樹 on 2015/11/29.
//  Copyright © 2015年 Yuki Yasoshima. All rights reserved.
//

import AVFoundation
import Accelerate

func hfsTypeCode(fileTypeString: String) -> OSType
{
    var result: OSType = 0
    var i: UInt32 = 0
    
    for uc in fileTypeString.unicodeScalars {
        result |= OSType(uc) << ((3 - i) * 8)
        ++i
    }
    
    return result;
}

func fillSine(out_data: UnsafeMutablePointer<Float32>, length: AVAudioFrameCount, startPhase: Float64, phasePerFrame: Float64) -> Float64
{
    if (out_data == nil || length == 0) {
        return startPhase;
    }
    
    var phase: Float64 = startPhase;
    
    for i in 0..<length {
        out_data[Int(i)] = Float32(phase)
        phase = fmod(phase + phasePerFrame, 2.0 * M_PI)
    }
    
    let len = [Int32(length)]
    vvsinf(out_data, out_data, len);
    
    return phase;
}

public typealias KernelRenderBlock = (buffer: AVAudioPCMBuffer) -> Void

class AudioUnitSampleKernel {
    var buffer: AVAudioPCMBuffer? {
        get {
            objc_sync_enter(self)
            let result = _buffer
            objc_sync_exit(self)
            return result
        }
        set {
            objc_sync_enter(self)
            _buffer = newValue
            objc_sync_exit(self)
        }
    }
    
    var renderBlock: KernelRenderBlock? {
        get {
            objc_sync_enter(self)
            let result = _renderBlock
            objc_sync_exit(self)
            return result
        }
        set {
            objc_sync_enter(self)
            _renderBlock = newValue
            objc_sync_exit(self)
        }
    }
    
    private var _buffer: AVAudioPCMBuffer?
    private var _renderBlock: KernelRenderBlock?
}
