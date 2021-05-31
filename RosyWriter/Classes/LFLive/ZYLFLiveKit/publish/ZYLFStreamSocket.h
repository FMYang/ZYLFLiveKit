//
//  LFStreamSocket.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZYLFLiveStreamInfo.h"
#import "ZYLFStreamingBuffer.h"
#import "ZYLFLiveDebug.h"



@protocol ZYLFStreamSocket;
@protocol ZYLFStreamSocketDelegate <NSObject>

/** callback buffer current status (回调当前缓冲区情况，可实现相关切换帧率 码率等策略)*/
- (void)socketBufferStatus:(nullable id <ZYLFStreamSocket>)socket status:(LFLiveBuffferState)status;
/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable id <ZYLFStreamSocket>)socket status:(LFLiveState)status;
/** callback socket errorcode */
- (void)socketDidError:(nullable id <ZYLFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode;
@optional
/** callback debugInfo */
- (void)socketDebug:(nullable id <ZYLFStreamSocket>)socket debugInfo:(nullable ZYLFLiveDebug *)debugInfo;
@end

@protocol ZYLFStreamSocket <NSObject>
- (void)start;
- (void)stop;
- (void)sendFrame:(nullable ZYLFFrame *)frame;
- (void)setDelegate:(nullable id <ZYLFStreamSocketDelegate>)delegate;
@optional
- (nullable instancetype)initWithStream:(nullable ZYLFLiveStreamInfo *)stream;
- (nullable instancetype)initWithStream:(nullable ZYLFLiveStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount;
@end
