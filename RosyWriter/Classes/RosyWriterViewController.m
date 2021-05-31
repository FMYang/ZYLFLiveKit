
/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller for camera interface
 */

#import "RosyWriterViewController.h"

#import <QuartzCore/QuartzCore.h>
#import "RosyWriterCapturePipeline.h"
#import "OpenGLPixelBufferView.h"
#import "LFLiveKit.h"

@interface RosyWriterViewController () <RosyWriterCapturePipelineDelegate,LFLiveSessionDelegate>
{
	BOOL _addedObservers;
	BOOL _recording;
	UIBackgroundTaskIdentifier _backgroundRecordingID;
	BOOL _allowedToUseGPU;
	
	NSTimer *_labelTimer;
	OpenGLPixelBufferView *_previewView;
	RosyWriterCapturePipeline *_capturePipeline;
}

@property(nonatomic, strong) IBOutlet UIBarButtonItem *recordButton;
@property(nonatomic, strong) IBOutlet UILabel *framerateLabel;
@property(nonatomic, strong) IBOutlet UILabel *dimensionsLabel;

@property (nonatomic, strong) LFLiveDebug *debugInfo;
@property (nonatomic, strong) LFLiveSession *session;

@end

@implementation RosyWriterViewController
#pragma mark -- Getter Setter
- (LFLiveSession *)session {
    if (!_session) {
        /**      发现大家有不会用横屏的请注意啦，横屏需要在ViewController  supportedInterfaceOrientations修改方向  默认竖屏  ****/
        /**      发现大家有不会用横屏的请注意啦，横屏需要在ViewController  supportedInterfaceOrientations修改方向  默认竖屏  ****/
        /**      发现大家有不会用横屏的请注意啦，横屏需要在ViewController  supportedInterfaceOrientations修改方向  默认竖屏  ****/


        /***   默认分辨率368 ＊ 640  音频：44.1 iphone6以上48  双声道  方向竖屏 ***/
        LFLiveVideoConfiguration *videoConfiguration = [LFLiveVideoConfiguration new];
        videoConfiguration.videoSize = CGSizeMake(640, 360);
        videoConfiguration.videoBitRate = 800*1024;
        videoConfiguration.videoMaxBitRate = 1000*1024;
        videoConfiguration.videoMinBitRate = 500*1024;
        videoConfiguration.videoFrameRate = 24;
        videoConfiguration.videoMaxKeyframeInterval = 48;
        videoConfiguration.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
        videoConfiguration.autorotate = NO;
        videoConfiguration.sessionPreset = LFCaptureSessionPreset720x1280;
        
        LFLiveAudioConfiguration *audioConfiguration = [LFLiveAudioConfiguration new];
        audioConfiguration.numberOfChannels = 1;
        audioConfiguration.audioBitrate = LFLiveAudioBitRate_64Kbps;
        audioConfiguration.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
//        _session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:videoConfiguration captureType:LFLiveInputMaskVideo|LFLiveCaptureMaskAudio];
        _session = [[LFLiveSession alloc] initWithAudioConfiguration:audioConfiguration videoConfiguration:videoConfiguration captureType:LFLiveInputMaskVideo];

        _session.delegate = self;
        _session.showDebugInfo = NO;
        
        
    }
    return _session;
}

/** live status changed will callback */
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state {
    NSLog(@"liveStateDidChange: %ld", state);
    
    switch (state) {
    case LFLiveReady:
        NSLog(@"LFLiveReady");
        break;
    case LFLivePending:
        NSLog(@"LFLivePending");
        break;
    case LFLiveStart:
        NSLog(@"LFLiveStart");
        break;
    case LFLiveError:
        NSLog(@"LFLiveError");
        break;
    case LFLiveStop:
        NSLog(@"LFLiveStop");

        break;
    default:
        break;
    }
}

/** live debug info callback */
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug *)debugInfo {

}

/** callback socket errorcode */
- (void)liveSession:(nullable LFLiveSession *)session errorCode:(LFLiveSocketErrorCode)errorCode {
    NSLog(@"errorCode: %ld", errorCode);
}

- (void)dealloc
{
	if ( _addedObservers )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
		[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	}
}

#pragma mark - View lifecycle

- (void)applicationDidEnterBackground
{
	// Avoid using the GPU in the background
	_allowedToUseGPU = NO;
	_capturePipeline.renderingEnabled = NO;

	[_capturePipeline stopRecording]; // a no-op if we aren't recording
	
	 // We reset the OpenGLPixelBufferView to ensure all resources have been cleared when going to the background.
	[_previewView reset];
}

- (void)applicationWillEnterForeground
{
	_allowedToUseGPU = YES;
	_capturePipeline.renderingEnabled = YES;
}

- (void)viewDidLoad
{
	_capturePipeline = [[RosyWriterCapturePipeline alloc] initWithDelegate:self callbackQueue:dispatch_get_main_queue()];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidEnterBackground)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationWillEnterForeground)
												 name:UIApplicationWillEnterForegroundNotification
											   object:[UIApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(deviceOrientationDidChange)
												 name:UIDeviceOrientationDidChangeNotification
											   object:[UIDevice currentDevice]];
	
	// Keep track of changes to the device orientation so we can update the capture pipeline
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	
	_addedObservers = YES;
	
	// the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
	_allowedToUseGPU = ( [UIApplication sharedApplication].applicationState != UIApplicationStateBackground );
	_capturePipeline.renderingEnabled = _allowedToUseGPU;
    [self requestAccessForAudio];
	[super viewDidLoad];
}
- (void)requestAccessForAudio {
    __weak typeof(self) _self = self;

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
//                    [_self.session setRunning:YES];
                });
            }

        }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        // 已经开启授权，可继续
        dispatch_async(dispatch_get_main_queue(), ^{
//            [_self.session setRunning:YES];
        });
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;
    default:
        break;
    }
}

-(NSData*) getAudioData: (CMSampleBufferRef)sampleBuffer{
    AudioBufferList audioBufferList;
    NSMutableData * videoData= [NSMutableData data];
    CMBlockBufferRef blockBuffer;
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,NULL,&audioBufferList,sizeof(audioBufferList),NULL,NULL,0,&blockBuffer);
    for (int y = 0 ; y<audioBufferList.mNumberBuffers; y++) {
        AudioBuffer audioBuffer = audioBufferList.mBuffers[y];
        Float32 *frame = (Float32*)audioBuffer.mData;

        NSData *data1 = [NSData dataWithBytes:frame length:audioBuffer.mDataByteSize];
        [videoData appendData:data1];
    }
    CFRelease(blockBuffer);
    return videoData;
}

-(void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline audioBuffer:(CMSampleBufferRef)audioBuffer{
    if (self.session.state == LFLiveStart) {
        [self.session pushAudio:[self getAudioData:audioBuffer]];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[_capturePipeline startRunning];
	
	_labelTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateLabels) userInfo:nil repeats:YES];

}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[_labelTimer invalidate];
	_labelTimer = nil;
	
	[_capturePipeline stopRunning];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

#pragma mark - UI

- (IBAction)toggleRecording:(id)sender
{
	if ( _recording )
	{
		[_capturePipeline stopRecording];
	}
	else
	{
		// Disable the idle timer while recording
		[UIApplication sharedApplication].idleTimerDisabled = YES;
		
		// Make sure we have time to finish saving the movie if the app is backgrounded during recording
		if ( [[UIDevice currentDevice] isMultitaskingSupported] ) {
			_backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
		}
		
		self.recordButton.enabled = NO; // re-enabled once recording has finished starting
		self.recordButton.title = @"Stop";
		
		[_capturePipeline startRecording];
		
		_recording = YES;
	}
}

- (void)recordingStopped
{
	_recording = NO;
	self.recordButton.enabled = YES;
	self.recordButton.title = @"Record";
	
	[UIApplication sharedApplication].idleTimerDisabled = NO;
	
	[[UIApplication sharedApplication] endBackgroundTask:_backgroundRecordingID];
	_backgroundRecordingID = UIBackgroundTaskInvalid;
}

- (void)setupPreviewView
{
	// Set up GL view
	_previewView = [[OpenGLPixelBufferView alloc] initWithFrame:CGRectZero];
	_previewView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	UIInterfaceOrientation currentInterfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
	_previewView.transform = [_capturePipeline transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)currentInterfaceOrientation withAutoMirroring:YES]; // Front camera preview should be mirrored

	[self.view insertSubview:_previewView atIndex:0];
	CGRect bounds = CGRectZero;
	bounds.size = [self.view convertRect:self.view.bounds toView:_previewView].size;
	_previewView.bounds = bounds;
	_previewView.center = CGPointMake( self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0 );
}

- (void)deviceOrientationDidChange
{
	UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
	
	// Update the recording orientation if the device changes to portrait or landscape orientation (but not face up/down)
	if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) )
	{
		_capturePipeline.recordingOrientation = (AVCaptureVideoOrientation)deviceOrientation;
	}
}

- (void)updateLabels
{	
	NSString *frameRateString = [NSString stringWithFormat:@"%d FPS", (int)roundf( _capturePipeline.videoFrameRate )];
	self.framerateLabel.text = frameRateString;
	
	NSString *dimensionsString = [NSString stringWithFormat:@"%d x %d", _capturePipeline.videoDimensions.width, _capturePipeline.videoDimensions.height];
	self.dimensionsLabel.text = dimensionsString;
}

- (void)showError:(NSError *)error
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:error.localizedDescription
														message:error.localizedFailureReason
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}

#pragma mark - RosyWriterCapturePipelineDelegate

- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline didStopRunningWithError:(NSError *)error
{
	[self showError:error];
	
	self.recordButton.enabled = NO;
}

// Preview
- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer
{
	if ( ! _allowedToUseGPU ) {
		return;
	}
	
	if ( ! _previewView ) {
		[self setupPreviewView];
	}
	
	[_previewView displayPixelBuffer:previewPixelBuffer];
    if (self.session.state == LFLiveStart) {
        NSLog(@"推送数据");
        [self.session pushVideo:previewPixelBuffer];
    }
}

- (void)capturePipelineDidRunOutOfPreviewBuffers:(RosyWriterCapturePipeline *)capturePipeline
{
	if ( _allowedToUseGPU ) {
		[_previewView flushPixelBufferCache];
	}
}

// Recording
- (void)capturePipelineRecordingDidStart:(RosyWriterCapturePipeline *)capturePipeline
{
	self.recordButton.enabled = YES;
    LFLiveStreamInfo *stream = [LFLiveStreamInfo new];
    stream.url = @"rtmp://123822.livepush.myqcloud.com/live/kkkk?txSecret=721723140559e456be5aa34d06b81577&txTime=60AF4BF4";
    [self.session startLive:stream];
}

- (void)capturePipelineRecordingWillStop:(RosyWriterCapturePipeline *)capturePipeline
{
	// Disable record button until we are ready to start another recording
	self.recordButton.enabled = NO;
	self.recordButton.title = @"Record";
}

- (void)capturePipelineRecordingDidStop:(RosyWriterCapturePipeline *)capturePipeline
{
	[self recordingStopped];
    [self.session stopLive];
}

- (void)capturePipeline:(RosyWriterCapturePipeline *)capturePipeline recordingDidFailWithError:(NSError *)error
{
	[self recordingStopped];
	[self showError:error];
}


@end
