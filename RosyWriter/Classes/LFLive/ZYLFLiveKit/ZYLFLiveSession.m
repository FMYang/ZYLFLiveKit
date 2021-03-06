//
//  LFLiveSession.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "ZYLFLiveSession.h"
#import "ZYLFAudioCapture.h"
#import "ZYLFHardwareVideoEncoder.h"
#import "ZYLFHardwareAudioEncoder.h"
#import "ZYLFH264VideoEncoder.h"
#import "ZYLFStreamRTMPSocket.h"
#import "ZYLFLiveStreamInfo.h"
#import "ZYLFH264VideoEncoder.h"


@interface ZYLFLiveSession ()<LFAudioCaptureDelegate, ZYLFAudioEncodingDelegate, ZYLFVideoEncodingDelegate, ZYLFStreamSocketDelegate>

/// 音频配置
@property (nonatomic, strong) ZYLFLiveAudioConfiguration *audioConfiguration;
/// 视频配置
@property (nonatomic, strong) ZYLFLiveVideoConfiguration *videoConfiguration;
/// 声音采集
@property (nonatomic, strong) ZYLFAudioCapture *audioCaptureSource;
/// 音频编码
@property (nonatomic, strong) id<ZYLFAudioEncoding> audioEncoder;
/// 视频编码
@property (nonatomic, strong) id<ZYLFVideoEncoding> videoEncoder;
/// 上传
@property (nonatomic, strong) id<ZYLFStreamSocket> socket;


#pragma mark -- 内部标识
/// 调试信息
@property (nonatomic, strong) ZYLFLiveDebug *debugInfo;
/// 流信息
@property (nonatomic, strong) ZYLFLiveStreamInfo *streamInfo;
/// 是否开始上传
@property (nonatomic, assign) BOOL uploading;
/// 当前状态
@property (nonatomic, assign, readwrite) LFLiveState state;
/// 当前直播type
@property (nonatomic, assign, readwrite) LFLiveCaptureTypeMask captureType;
/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;


@end

/**  时间戳 */
#define NOW (CACurrentMediaTime()*1000)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface ZYLFLiveSession ()

/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;
/// 音视频是否对齐
@property (nonatomic, assign) BOOL AVAlignment;
/// 当前是否采集到了音频
@property (nonatomic, assign) BOOL hasCaptureAudio;
/// 当前是否采集到了关键帧
@property (nonatomic, assign) BOOL hasKeyFrameVideo;

@end

@implementation ZYLFLiveSession

#pragma mark -- LifeCycle
- (instancetype)initWithAudioConfiguration:(nullable ZYLFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(nullable ZYLFLiveVideoConfiguration *)videoConfiguration {
    return [self initWithAudioConfiguration:audioConfiguration videoConfiguration:videoConfiguration captureType:LFLiveCaptureDefaultMask];
}

- (nullable instancetype)initWithAudioConfiguration:(nullable ZYLFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(nullable ZYLFLiveVideoConfiguration *)videoConfiguration captureType:(LFLiveCaptureTypeMask)captureType{
    if((captureType & LFLiveCaptureMaskAudio || captureType & LFLiveInputMaskAudio) && !audioConfiguration) @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"audioConfiguration is nil " userInfo:nil];
    if((captureType & LFLiveCaptureMaskVideo || captureType & LFLiveInputMaskVideo) && !videoConfiguration) @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"videoConfiguration is nil " userInfo:nil];
    if (self = [super init]) {
        _audioConfiguration = audioConfiguration;
        _videoConfiguration = videoConfiguration;
        _adaptiveBitrate = NO;
        _captureType = captureType;
    }
    return self;
}

- (void)dealloc {
    _audioCaptureSource.running = NO;
}

#pragma mark -- CustomMethod
- (void)startLive:(ZYLFLiveStreamInfo *)streamInfo {
    if (!streamInfo) return;
    _streamInfo = streamInfo;
    _streamInfo.videoConfiguration = _videoConfiguration;
    _streamInfo.audioConfiguration = _audioConfiguration;
    [self.socket start];
}

- (void)stopLive {
    self.uploading = NO;
    [self.socket stop];
    self.socket = nil;
}

- (void)pushVideo:(nullable CVPixelBufferRef)pixelBuffer{
    if(self.captureType & LFLiveInputMaskVideo){
        if (self.uploading) [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:NOW];
    }
}

- (void)pushAudio:(nullable NSData*)audioData{
    if(self.captureType & LFLiveInputMaskAudio){
        if (self.uploading) [self.audioEncoder encodeAudioData:audioData timeStamp:NOW];
    }
}

#pragma mark -- PrivateMethod
- (void)pushSendBuffer:(ZYLFFrame*)frame{
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.socket sendFrame:frame];
}

#pragma mark -- CaptureDelegate
- (void)captureOutput:(nullable ZYLFAudioCapture *)capture audioData:(nullable NSData*)audioData {
    if (self.uploading) [self.audioEncoder encodeAudioData:audioData timeStamp:NOW];
}


#pragma mark -- EncoderDelegate
- (void)audioEncoder:(nullable id<ZYLFAudioEncoding>)encoder audioFrame:(nullable ZYLFAudioFrame *)frame {
    //<上传  时间戳对齐
    if (self.uploading){
        self.hasCaptureAudio = YES;
        if(self.AVAlignment) [self pushSendBuffer:frame];
    }
}

- (void)videoEncoder:(nullable id<ZYLFVideoEncoding>)encoder videoFrame:(nullable ZYLFVideoFrame *)frame {
    //<上传 时间戳对齐
    if (self.uploading){
        if(frame.isKeyFrame && self.hasCaptureAudio) self.hasKeyFrameVideo = YES;
        if(self.AVAlignment) [self pushSendBuffer:frame];
    }
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<ZYLFStreamSocket>)socket status:(LFLiveState)status {
    if (status == LFLiveStart) {
        if (!self.uploading) {
            self.AVAlignment = NO;
            self.hasCaptureAudio = NO;
            self.hasKeyFrameVideo = NO;
            self.relativeTimestamps = 0;
            self.uploading = YES;
        }
    } else if(status == LFLiveStop || status == LFLiveError){
        self.uploading = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = status;
        if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:liveStateDidChange:)]) {
            [self.delegate liveSession:self liveStateDidChange:status];
        }
    });
}

- (void)socketDidError:(nullable id<ZYLFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:errorCode:)]) {
            [self.delegate liveSession:self errorCode:errorCode];
        }
    });
}

- (void)socketDebug:(nullable id<ZYLFStreamSocket>)socket debugInfo:(nullable ZYLFLiveDebug *)debugInfo {
    self.debugInfo = debugInfo;
    if (self.showDebugInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:debugInfo:)]) {
                [self.delegate liveSession:self debugInfo:debugInfo];
            }
        });
    }
}

- (void)socketBufferStatus:(nullable id<ZYLFStreamSocket>)socket status:(LFLiveBuffferState)status {
    if((self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo) && self.adaptiveBitrate){
        NSUInteger videoBitRate = [self.videoEncoder videoBitRate];
        if (status == LFLiveBuffferDecline) {
            if (videoBitRate < _videoConfiguration.videoMaxBitRate) {
                videoBitRate = videoBitRate + 50 * 1000;
                [self.videoEncoder setVideoBitRate:videoBitRate];
                NSLog(@"Increase bitrate %@", @(videoBitRate));
            }
        } else {
            if (videoBitRate > self.videoConfiguration.videoMinBitRate) {
                videoBitRate = videoBitRate - 100 * 1000;
                [self.videoEncoder setVideoBitRate:videoBitRate];
                NSLog(@"Decline bitrate %@", @(videoBitRate));
            }
        }
    }
}

#pragma mark -- Getter Setter
- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    [self willChangeValueForKey:@"running"];
    _running = running;
    [self didChangeValueForKey:@"running"];
    self.audioCaptureSource.running = _running;
}
- (void)setMuted:(BOOL)muted {
    [self willChangeValueForKey:@"muted"];
    [self.audioCaptureSource setMuted:muted];
    [self didChangeValueForKey:@"muted"];
}

- (BOOL)muted {
    return self.audioCaptureSource.muted;
}

- (ZYLFAudioCapture *)audioCaptureSource {
    if (!_audioCaptureSource) {
        if(self.captureType & LFLiveCaptureMaskAudio){
            _audioCaptureSource = [[ZYLFAudioCapture alloc] initWithAudioConfiguration:_audioConfiguration];
            _audioCaptureSource.delegate = self;
        }
    }
    return _audioCaptureSource;
}

- (id<ZYLFAudioEncoding>)audioEncoder {
    if (!_audioEncoder) {
        _audioEncoder = [[ZYLFHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:_audioConfiguration];
        [_audioEncoder setDelegate:self];
    }
    return _audioEncoder;
}

- (id<ZYLFVideoEncoding>)videoEncoder {
    if (!_videoEncoder) {
        if([[UIDevice currentDevice].systemVersion floatValue] < 8.0){
            _videoEncoder = [[ZYLFH264VideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        }else{
            _videoEncoder = [[ZYLFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        }
        [_videoEncoder setDelegate:self];
    }
    return _videoEncoder;
}

- (id<ZYLFStreamSocket>)socket {
    if (!_socket) {
        _socket = [[ZYLFStreamRTMPSocket alloc] initWithStream:self.streamInfo reconnectInterval:self.reconnectInterval reconnectCount:self.reconnectCount];
        [_socket setDelegate:self];
    }
    return _socket;
}

- (ZYLFLiveStreamInfo *)streamInfo {
    if (!_streamInfo) {
        _streamInfo = [[ZYLFLiveStreamInfo alloc] init];
    }
    return _streamInfo;
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (BOOL)AVAlignment{
    if((self.captureType & LFLiveCaptureMaskAudio || self.captureType & LFLiveInputMaskAudio) &&
       (self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo)
       ){
        if(self.hasCaptureAudio && self.hasKeyFrameVideo) return YES;
        else  return NO;
    }else{
        return YES;
    }
}

@end
