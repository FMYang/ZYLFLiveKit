
 /*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The class that creates and manages the AVCaptureSession
 */


#import <AVFoundation/AVFoundation.h>

@protocol RosyWriterCapturePipelineDelegate;

@interface RosyWriterCapturePipeline : NSObject 

- (instancetype)initWithDelegate:(id<RosyWriterCapturePipelineDelegate>)delegate callbackQueue:(dispatch_queue_t)queue; // delegate is weak referenced

// These methods are synchronous
- (void)startRunning;
- (void)stopRunning;

// Must be running before starting recording
// These methods are asynchronous, see the recording delegate callbacks
- (void)startRecording;
- (void)stopRecording;

@property(atomic) BOOL renderingEnabled; // When set to NO the GPU will not be used after the setRenderingEnabled: call returns.

@property(atomic) AVCaptureVideoOrientation recordingOrientation; // client can set the orientation for the recorded movie

- (CGAffineTransform)transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)orientation withAutoMirroring:(BOOL)mirroring; // only valid after startRunning has been called

// Stats
@property(atomic, readonly) float videoFrameRate;
@property(atomic, readonly) CMVideoDimensions videoDimensions;

@end

@protocol RosyWriterCapturePipelineDelegate <NSObject>
@required

- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline didStopRunningWithError:(NSError *)error;

- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline audioBuffer:(CMSampleBufferRef)audioBuffer;

// Preview
- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer;
- (void)capturePipelineDidRunOutOfPreviewBuffers:(RosyWriterCapturePipeline *)capturePipeline;

// Recording
- (void)capturePipelineRecordingDidStart:(RosyWriterCapturePipeline *)capturePipeline;
- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline recordingDidFailWithError:(NSError *)error; // Can happen at any point after a startRecording call, for example: startRecording->didFail (without a didStart), willStop->didFail (without a didStop)
- (void)capturePipelineRecordingWillStop:(RosyWriterCapturePipeline *)capturePipeline;
- (void)capturePipelineRecordingDidStop:(RosyWriterCapturePipeline *)capturePipeline;

@end
