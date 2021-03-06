//
//  LFStreamingBuffer.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZYLFAudioFrame.h"
#import "ZYLFVideoFrame.h"


/** current buffer status */
typedef NS_ENUM (NSUInteger, LFLiveBuffferState) {
    LFLiveBuffferUnknown = 0,      //< 未知
    LFLiveBuffferIncrease = 1,    //< 缓冲区状态差应该降低码率
    LFLiveBuffferDecline = 2      //< 缓冲区状态好应该提升码率
};

@class ZYLFStreamingBuffer;
/** this two method will control videoBitRate */
@protocol LFStreamingBufferDelegate <NSObject>
@optional
/** 当前buffer变动（增加or减少） 根据buffer中的updateInterval时间回调*/
- (void)streamingBuffer:(nullable ZYLFStreamingBuffer *)buffer bufferState:(LFLiveBuffferState)state;
@end

@interface ZYLFStreamingBuffer : NSObject


/** The delegate of the buffer. buffer callback */
@property (nullable, nonatomic, weak) id <LFStreamingBufferDelegate> delegate;

/** current frame buffer */
@property (nonatomic, strong, readonly) NSMutableArray <ZYLFFrame *> *_Nonnull list;

/** buffer count max size default 1000 */
@property (nonatomic, assign) NSUInteger maxCount;

/** count of drop frames in last time */
@property (nonatomic, assign) NSInteger lastDropFrames;

/** add frame to buffer */
- (void)appendObject:(nullable ZYLFFrame *)frame;

/** pop the first frome buffer */
- (nullable ZYLFFrame *)popFirstObject;

/** remove all objects from Buffer */
- (void)removeAllObject;

@end
