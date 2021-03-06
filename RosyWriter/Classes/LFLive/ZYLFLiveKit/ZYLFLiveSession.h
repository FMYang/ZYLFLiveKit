//
//  LFLiveSession.h
//  LFLiveKit
//
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ZYLFLiveStreamInfo.h"
#import "ZYLFAudioFrame.h"
#import "ZYLFVideoFrame.h"
#import "ZYLFLiveAudioConfiguration.h"
#import "ZYLFLiveVideoConfiguration.h"
#import "ZYLFLiveDebug.h"



typedef NS_ENUM(NSInteger,LFLiveCaptureType) {
    LFLiveCaptureAudio,         //< capture only audio
    LFLiveCaptureVideo,         //< capture onlt video
    LFLiveInputAudio,           //< only audio (External input audio)
    LFLiveInputVideo,           //< only video (External input video)
};


///< 用来控制采集类型（可以内部采集也可以外部传入等各种组合，支持单音频与单视频,外部输入适用于录屏，无人机等外设介入）
typedef NS_ENUM(NSInteger,LFLiveCaptureTypeMask) {
    LFLiveCaptureMaskAudio = (1 << LFLiveCaptureAudio),                                 ///< only inner capture audio (no video)
    LFLiveCaptureMaskVideo = (1 << LFLiveCaptureVideo),                                 ///< only inner capture video (no audio)
    LFLiveInputMaskAudio = (1 << LFLiveInputAudio),                                     ///< only outer input audio (no video)
    LFLiveInputMaskVideo = (1 << LFLiveInputVideo),                                     ///< only outer input video (no audio)
    LFLiveCaptureMaskAll = (LFLiveCaptureMaskAudio | LFLiveCaptureMaskVideo),           ///< inner capture audio and video
    LFLiveInputMaskAll = (LFLiveInputMaskAudio | LFLiveInputMaskVideo),                 ///< outer input audio and video(method see pushVideo and pushAudio)
    LFLiveCaptureMaskAudioInputVideo = (LFLiveCaptureMaskAudio | LFLiveInputMaskVideo), ///< inner capture audio and outer input video(method pushVideo and setRunning)
    LFLiveCaptureMaskVideoInputAudio = (LFLiveCaptureMaskVideo | LFLiveInputMaskAudio), ///< inner capture video and outer input audio(method pushAudio and setRunning)
    LFLiveCaptureDefaultMask = LFLiveCaptureMaskAll                                     ///< default is inner capture audio and video
};

@class ZYLFLiveSession;
@protocol LFLiveSessionDelegate <NSObject>

@optional
/** live status changed will callback */
- (void)liveSession:(nullable ZYLFLiveSession *)session liveStateDidChange:(LFLiveState)state;
/** live debug info callback */
- (void)liveSession:(nullable ZYLFLiveSession *)session debugInfo:(nullable ZYLFLiveDebug *)debugInfo;
/** callback socket errorcode */
- (void)liveSession:(nullable ZYLFLiveSession *)session errorCode:(LFLiveSocketErrorCode)errorCode;
@end

@class ZYLFLiveStreamInfo;

@interface ZYLFLiveSession : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/** The delegate of the capture. captureData callback */
@property (nullable, nonatomic, weak) id<LFLiveSessionDelegate> delegate;
/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

/** The muted control callbackAudioData,muted will memset 0.*/
@property (nonatomic, assign) BOOL muted;

/*  The adaptiveBitrate control auto adjust bitrate. Default is NO */
@property (nonatomic, assign) BOOL adaptiveBitrate;

/** The stream control upload and package*/
@property (nullable, nonatomic, strong, readonly) ZYLFLiveStreamInfo *streamInfo;

/** The status of the stream .*/
@property (nonatomic, assign, readonly) LFLiveState state;

/** The captureType control inner or outer audio and video .*/
@property (nonatomic, assign, readonly) LFLiveCaptureTypeMask captureType;

/** The showDebugInfo control streamInfo and uploadInfo(1s) *.*/
@property (nonatomic, assign) BOOL showDebugInfo;

/** The reconnectInterval control reconnect timeInterval(重连间隔) *.*/
@property (nonatomic, assign) NSUInteger reconnectInterval;

/** The reconnectCount control reconnect count (重连次数) *.*/
@property (nonatomic, assign) NSUInteger reconnectCount;



#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
   The designated initializer. Multiple instances with the same configuration will make the
   capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable ZYLFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(nullable ZYLFLiveVideoConfiguration *)videoConfiguration;

/**
 The designated initializer. Multiple instances with the same configuration will make the
 capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable ZYLFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(nullable ZYLFLiveVideoConfiguration *)videoConfiguration captureType:(LFLiveCaptureTypeMask)captureType NS_DESIGNATED_INITIALIZER;

/** The start stream .*/
- (void)startLive:(nonnull ZYLFLiveStreamInfo *)streamInfo;

/** The stop stream .*/
- (void)stopLive;

/** support outer input yuv or rgb video(set LFLiveCaptureTypeMask) .*/
- (void)pushVideo:(nullable CVPixelBufferRef)pixelBuffer;

/** support outer input pcm audio(set LFLiveCaptureTypeMask) .*/
- (void)pushAudio:(nullable NSData*)audioData;

@end

