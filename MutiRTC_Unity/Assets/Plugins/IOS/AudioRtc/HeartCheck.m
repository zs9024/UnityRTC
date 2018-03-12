//
//  HeartCheck.m
//  Unity-iPhone
//
//  Created by waking on 17/4/19.
//
//

#import <Foundation/Foundation.h>
#import "HeartCheck.h"

const NSInteger HEART_BEAT_RATE = 10;
const NSInteger TIMEOUT_RATE = 5;

@implementation HeartCheck 
{
    SRWebSocket *_socket;
}

- (id)initWithWebsocket:(SRWebSocket *)socket
{
    if (self=[super init]) {
        _socket = socket;
    }
    
    return self;
}

- (void)start
{
    [self performSelector:@selector(dealHeart:) withObject:nil afterDelay:HEART_BEAT_RATE];
}

- (void)reset
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dealHeart:) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dealTimeout:) object:nil];
    [self start];
}

- (void)stop
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_socket && (_socket.readyState != SR_CLOSING || _socket.readyState != SR_CLOSED))
    {
        [_socket close];
        _socket = nil;
    }
}

- (void)dealHeart : (id)sender {
    //NSLog(@"dealHeart: %@",sender);

    [self sendHeart];
    [self performSelector:@selector(dealTimeout:) withObject:nil afterDelay:TIMEOUT_RATE];
}

- (void)sendHeart {
    if (_socket != nil && _socket.readyState == SR_OPEN)
    {
        [_socket send:@"_heratbeat"];
    }
}

- (void)dealTimeout : (id)sender {
    NSLog(@"dealTimeout: %@",sender);
    [self reconnect];
}

- (void)reconnect {
    [[NSNotificationCenter defaultCenter] postNotificationName:WebsocketReconnectNotification object:nil];
}

@end
