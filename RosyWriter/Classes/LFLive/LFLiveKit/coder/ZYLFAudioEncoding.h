//
//  LFAudioEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFAudioFrame.h"
#import "ZYLFLiveAudioConfiguration.h"



@protocol ZYLFAudioEncoding;
/// 编码器编码后回调
@protocol ZYLFAudioEncodingDelegate <NSObject>
@required
- (void)audioEncoder:(nullable id<ZYLFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame *)frame;
@end

/// 编码器抽象的接口
@protocol ZYLFAudioEncoding <NSObject>
@required
- (void)encodeAudioData:(nullable NSData*)audioData timeStamp:(uint64_t)timeStamp;
- (void)stopEncoder;
@optional
- (nullable instancetype)initWithAudioStreamConfiguration:(nullable ZYLFLiveAudioConfiguration *)configuration;
- (void)setDelegate:(nullable id<ZYLFAudioEncodingDelegate>)delegate;
- (nullable NSData *)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength;
@end

