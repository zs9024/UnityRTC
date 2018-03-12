//
//  HeartCheck.h
//  Unity-iPhone
//
//  Created by waking on 17/4/19.
//
//

#ifndef HeartCheck_h
#define HeartCheck_h

#import "SocketRocket.h"

NSString *const WebsocketReconnectNotification = @"WebsocketReconnectNotification";

@interface HeartCheck : NSObject
- (id)initWithWebsocket:(SRWebSocket *)socket;
- (void)start;
- (void)reset;
- (void)stop;

@end


#endif /* HeartCheck_h */
