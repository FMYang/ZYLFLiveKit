//
//  LFVideoEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZYLFVideoFrame.h"
#import "ZYLFLiveVideoConfiguration.h"

@protocol ZYLFVideoEncoding;
/// 编码器编码后回调
@protocol ZYLFVideoEncodingDelegate <NSObject>
@required
- (void)videoEncoder:(nullable id<ZYLFVideoEncoding>)encoder videoFrame:(nullable ZYLFVideoFrame *)frame;
@end

/// 编码器抽象的接口
@protocol ZYLFVideoEncoding <NSObject>
@required
- (void)encodeVideoData:(nullable CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;
@optional
@property (nonatomic, assign) NSInteger videoBitRate;
- (nullable instancetype)initWithVideoStreamConfiguration:(nullable ZYLFLiveVideoConfiguration *)configuration;
- (void)setDelegate:(nullable id<ZYLFVideoEncodingDelegate>)delegate;
- (void)stopEncoder;
@end

