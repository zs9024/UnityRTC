//
//  WebRTCHelper.h
//  WebScoketTest
//
//

#import <Foundation/Foundation.h>
#import "SocketRocket.h"
#import "RTCMediaStream.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCPeerConnection.h"
#import "RTCPair.h"
#import "RTCMediaConstraints.h"
#import "RTCAudioTrack.h"
#import "RTCVideoTrack.h"
#import "RTCVideoCapturer.h"
#import "RTCSessionDescription.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCEAGLVideoView.h"
#import "RTCICEServer.h"
#import "RTCVideoSource.h"
#import "RTCAVFoundationVideoSource.h"
#import "RTCICECandidate.h"
#import "HeartCheck.h"
#import <MediaPlayer/MediaPlayer.h>

@protocol WebRTCHelperDelegate;

@interface WebRTCHelper : NSObject<SRWebSocketDelegate>

+ (instancetype)sharedInstance;

@property (nonatomic, weak)id<WebRTCHelperDelegate> delegate;

/**
 *  与服务器建立连接
 *  @param server 服务器地址
    @pram  port   端口号
 *  @param room   房间号
 */
- (void)connectServer:(NSString *)server port:(NSString *)port iceServers:(NSArray *)iceServers;

- (void)joinRoom:(NSString *)room enableVideo:(BOOL)enable;

- (void)activeLocalStream:(BOOL)active;

- (void)activeRemoteStream:(BOOL)active;

- (void)enableSpeaker:(BOOL)enable;

- (void)closePeerConnections;

/**
 *  退出房间
 */
- (void)exitRoom;
@end

@protocol WebRTCHelperDelegate <NSObject>

@optional
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper setLocalStream:(RTCMediaStream *)stream userId:(NSString *)userId;
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper addRemoteStream:(RTCMediaStream *)stream userId:(NSString *)userId;
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper closeWithUserId:(NSString *)userId;

//outer interface for server's notification
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeConnected:(NSString *)msg;
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeJoinedRoom:(NSArray *)peersId myId:(NSString *)myId;
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeNewPeerJoinRomm:(NSString *)userId;
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeDisconnectRoom:(NSString *)msg;
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticePCClosed:(NSString *)userId;
@end
