//
//  WebRTCHelper.m
//  WebScoketTest
//

//  WebRTCHelper.m
//  WebRTCDemo
//


#import "WebRTCHelper.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
//#import "SoundRouter.h"

//主线程异步队列
#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

//#define DEBUG

//第三方ice
static NSString *const RTCSTUNServerURL = @"stun:numb.viagenie.ca:3478";
static NSString *const RTCTURNServerURL = @"turn:numb.viagenie.ca";

typedef enum : NSUInteger {
    //发送者
    RoleCaller,
    //被发送者
    RoleCallee,
} Role;

@interface WebRTCHelper ()<RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>

@property(nonatomic, strong) RTCAudioTrack *defaultAudioTrack;
@property(nonatomic, strong) RTCVideoTrack *defaultVideoTrack;
@property(nonatomic, assign) BOOL isSpeakerEnabled;
@property(nonatomic, assign) BOOL isAudioRoutInited;

@end

@implementation WebRTCHelper
{
    SRWebSocket *_socket;
    NSString *_server;
    NSString *_port;
    NSString *_room;
    NSArray *_iceServers;           //string array
    
    RTCPeerConnectionFactory *_factory;
    RTCMediaStream *_localStream;
    
    NSString *_myId;
    NSMutableDictionary *_connectionDic;
    NSMutableArray *_connectionIdArray;
    
    //触发当前操作的socketID
    NSString *_currentId;
    Role _role;
    
    NSMutableArray *ICEServers;     //ice array
    
    BOOL _useVideo;
    NSMutableDictionary *_remoteStreams; //RTCMediaStreams
    
    HeartCheck *heartCheck;
    BOOL _roomConnectionWorking;
}

@synthesize isSpeakerEnabled = _isSpeakerEnabled;
@synthesize isAudioRoutInited = _isAudioRoutInited;

static WebRTCHelper *instance = nil;

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
        [instance initData];

    });
    return instance;
}

- (void)initData
{
    _connectionDic = [NSMutableDictionary dictionary];
    _connectionIdArray = [NSMutableArray array];
    _remoteStreams = [NSMutableDictionary dictionary];
}

/***********************************************************************************************************************/
//服务器连接与房间操作 
/***********************************************************************************************************************/
/**
 *  与服务器建立连接
 *
 *  @param server 服务器地址
 *  @param room   房间号
 */
- (void)connectServer:(NSString *)server port:(NSString *)port iceServers:(NSArray *)iceServers
{
    //[self getCurrentCategory:@"connectServer"];
    
    //server = @"172.16.130.6";
    _server = server;
    _port = port;
    _iceServers = iceServers;

    [self connectServer];
}

- (void)connectServer
{
    _roomConnectionWorking = YES;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"ws://%@:%@",_server,_port]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    _socket = [[SRWebSocket alloc] initWithURLRequest:request];
    _socket.delegate = self;
    [_socket open];
    
    //start check heart beating
    [self initHeartCheck:_socket];
}

/**
 *  加入房间
 *
 *  @param room 房间号
 */
- (void)joinRoom:(NSString *)room enableVideo:(BOOL)enable
{
    //[self setAudioSessionActive:1];
    _useVideo = enable;
    
    //如果socket是打开状态
    if (_socket.readyState == SR_OPEN)
    {
        //初始化加入房间的类型参数 room房间号
        NSDictionary *dic = @{@"eventName": @"__join", @"data": @{@"room": room}};
        
        //得到json的data
        NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
        //发送加入房间的数据
        [_socket send:data];
    }
}
/**
 *  退出房间
 */
- (void)exitRoom
{
    _roomConnectionWorking = NO;
    _isSpeakerEnabled = NO;
    
    _localStream = nil;
   
    [self closePeerConnections];
    if (_factory) {
        [RTCPeerConnectionFactory deinitializeSSL];
        _factory = nil;
    }
    
    if (_socket && _socket.readyState != SR_CLOSING && _socket.readyState != SR_CLOSED) {
        [_socket close];
    }
    
    [self destroyHeartCheck];
}

/***********************************************************************************************************************/
//WebSocketDelegate
/***********************************************************************************************************************/
#pragma mark--SRWebSocketDelegate
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
#ifdef DEBUG
    NSLog(@"收到服务器消息:%@",message);
#endif
    
    //heartbeat
    if ([message isEqualToString:@"_heratbeat"]) {
        if (_socket && _socket.readyState == SR_OPEN) {
            [_socket send:@"__heratbeat"];
        }
        [heartCheck reset];
        return;
    }
    if ([message isEqualToString:@"__heratbeat"]) {
        [heartCheck reset];
        return;
    }
    
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString *eventName = dic[@"eventName"];

    //1.发送加入房间后的反馈
    if ([eventName isEqualToString:@"_peers"])
    {
        //得到data
        NSDictionary *dataDic = dic[@"data"];
        //得到所有的连接
        NSArray *connections = dataDic[@"connections"];
        //加到连接数组中去
        [_connectionIdArray addObjectsFromArray:connections];
        
        //拿到给自己分配的ID
        _myId = dataDic[@"you"];
      
        //如果为空，则创建点对点工厂
        if (!_factory)
        {
            //设置SSL传输
            [RTCPeerConnectionFactory initializeSSL];
            _factory = [[RTCPeerConnectionFactory alloc] init];
        }
        //如果本地视频流为空
        if (!_localStream)
        {
            //创建本地流
            [self createLocalStream];
        }
        //创建连接
        [self createPeerConnections];
        
        //添加
        [self addStreams];
        [self createOffers];
        
        //delegate join room sucecess
        if ([_delegate respondsToSelector:@selector(webRTCHelper:noticeJoinedRoom:myId:)])
        {
            [_delegate webRTCHelper:self noticeJoinedRoom:connections myId:_myId];
            
        }
        
    }
    //4.接收到新加入的人发了ICE候选，（即经过ICEServer而获取到的地址）
    else if ([eventName isEqualToString:@"_ice_candidate"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        NSString *sdpMid = dataDic[@"id"];
        NSInteger sdpMLineIndex = [dataDic[@"label"] integerValue];
        NSString *sdp = dataDic[@"candidate"];
        //生成远端网络地址对象
        RTCICECandidate *candidate = [[RTCICECandidate alloc] initWithMid:sdpMid index:sdpMLineIndex sdp:sdp];
        //拿到当前对应的点对点连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //添加到点对点连接中
        [peerConnection addICECandidate:candidate];
    }
    //2.其他新人加入房间的信息
    else if ([eventName isEqualToString:@"_new_peer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        //拿到新人的ID
        NSString *socketId = dataDic[@"socketId"];
        //再去创建一个连接
        RTCPeerConnection *peerConnection = [self createPeerConnection:socketId];
        if (peerConnection == nil) {
            NSLog(@"create peerconnection failed !");
            return;
        }
        
        if (!_localStream)
        {
            [self createLocalStream];
        }
        //把本地流加到连接中去
        [peerConnection addStream:_localStream];
        //连接ID新加一个
        [_connectionIdArray addObject:socketId];
        //并且设置到Dic中去
        [_connectionDic setObject:peerConnection forKey:socketId];
        
        //delegate new peer join room
        if ([_delegate respondsToSelector:@selector(webRTCHelper:noticeNewPeerJoinRomm:)])
        {
            [_delegate webRTCHelper:self noticeNewPeerJoinRomm:socketId];
        }
    }
    //有人离开房间的事件
    else if ([eventName isEqualToString:@"_remove_peer"])
    {
        //得到socketId，关闭这个peerConnection
        NSDictionary *dataDic = dic[@"data"];
        NSString *socketId = dataDic[@"socketId"];
        [self closePeerConnection:socketId];
    }
    //这个新加入的人发了个offer
    else if ([eventName isEqualToString:@"_offer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        //拿到SDP
        NSString *sdp = sdpDic[@"sdp"];
        NSString *type = sdpDic[@"type"];
        NSString *socketId = dataDic[@"socketId"];
        
        //拿到这个点对点的连接
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        //根据类型和SDP 生成SDP描述对象
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:type sdp:sdp];
        //设置给这个点对点连接
        [peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:remoteSdp];
        
        //把当前的ID保存下来
        _currentId = socketId;
        //设置当前角色状态为被呼叫，（被发offer）
        _role = RoleCallee;
    }
    //回应offer
    else if ([eventName isEqualToString:@"_answer"])
    {
        NSDictionary *dataDic = dic[@"data"];
        NSDictionary *sdpDic = dataDic[@"sdp"];
        NSString *sdp = sdpDic[@"sdp"];
        NSString *type = sdpDic[@"type"];
        NSString *socketId = dataDic[@"socketId"];
        RTCPeerConnection *peerConnection = [_connectionDic objectForKey:socketId];
        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:type sdp:sdp];
        [peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:remoteSdp];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
#ifdef DEBUG
    NSLog(@"websocket建立成功");
#endif
    
//    NSLog(@"[webSocketDidOpen] 当前线程  %@",[NSThread currentThread]);
//    NSLog(@"[webSocketDidOpen] 主线程    %@",[NSThread mainThread]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_delegate respondsToSelector:@selector(webRTCHelper:noticeConnected:)])
        {
            [_delegate webRTCHelper:self noticeConnected:@"websocket建立成功"];
        }
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
    NSLog(@"readyState = %ld;code = %ld;reason = %@",(long)webSocket.readyState,(long)error.code, error.localizedDescription);
    NSLog(@"_socket state = %ld",(long)_socket.readyState);
#endif
    
    //54:server disconnect 57:socket not connected 50:network is down
    //锁屏后开屏readyState = 3;code = 2145;reason = Error writing to stream
    if (webSocket.readyState == SR_CLOSING||(webSocket.readyState == SR_CLOSED && error.code != 50)
        ||(webSocket.readyState == SR_OPEN && error.code == 57)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([_delegate respondsToSelector:@selector(webRTCHelper:noticeDisconnectRoom:)])
            {
                [_delegate webRTCHelper:self noticeDisconnectRoom:@""];
            }
        });
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
    NSLog(@"readyState = %ld;code = %ld;reason = %@",(long)webSocket.readyState,(long)code, reason);
#endif
    
    if (webSocket.readyState == SR_CLOSING || webSocket.readyState == SR_CLOSED) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([_delegate respondsToSelector:@selector(webRTCHelper:noticeDisconnectRoom:)])
            {
                [_delegate webRTCHelper:self noticeDisconnectRoom:@""];
            }
        });
    }
    
    //close normally,dispose heart
    //if (code == 1000) {
    //    [self destroyHeartCheck];
    //}
}

/***********************************************************************************************************************/
//PeerConnection相关
/***********************************************************************************************************************/
/**
 *  关闭所有pc连接
 */
- (void)closePeerConnections
{
    /*[_connectionIdArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self closePeerConnection:obj];
    }];*/
    //遍历中有删除，使用倒序
    for(int i = [_connectionIdArray count] - 1;i >= 0 ;i--)
    {
        NSString * connectionId = [_connectionIdArray objectAtIndex:i];
        [self closePeerConnection:connectionId];
    }
    
    [self removeLocalStream];
}
/**
 *  关闭peerConnection
 *
 *  @param connectionId <#connectionId description#>
 */
- (void)closePeerConnection:(NSString *)connectionId
{
    NSLog(@"[closePeerConnection] connectionId = %@",connectionId);
    
    //[self addNoticeObserver];
    
    RTCPeerConnection *peerConnection = [_connectionDic objectForKey:connectionId];
    if (!peerConnection) {
        NSLog(@"[closePeerConnection] exception: peerConnection is nil !");
        return;
    }
    //must asset empty
    RTCMediaStream *localStream = peerConnection.localStreams[0];
    if (localStream) {
        [peerConnection removeStream:localStream];
    }
    [self removeRemoteStream:connectionId];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
        [[AVAudioSession sharedInstance]setActive:true error:nil];
        _isSpeakerEnabled = NO;
        //[self enableSpeaker:NO];
        //[self getCurrentCategory:@"closePeerConnection"];
    });

    [peerConnection close];
    [_connectionIdArray removeObject:connectionId];
    [_connectionDic removeObjectForKey:connectionId];
    
    if (_useVideo == NO)
    {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_delegate respondsToSelector:@selector(webRTCHelper:closeWithUserId:)])
        {
            [_delegate webRTCHelper:self closeWithUserId:connectionId];
        }
    });
}

- (void)removeLocalStream
{
    if (_localStream) {
        if (_localStream.audioTracks && _localStream.audioTracks.count >0) {
            [_localStream removeAudioTrack:_localStream.audioTracks[0]];
            _localStream = nil;
        }
    }
}

- (void)removeRemoteStream:(NSString *) userId
{
    if (_remoteStreams) {
        [_remoteStreams enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, RTCMediaStream *ms, BOOL * _Nonnull stop) {
            if ([userId isEqualToString:key]) {
                if (!ms || !ms.audioTracks || ms.audioTracks.count <= 0)
                {
                    return ;
                }
                for (RTCAudioTrack * at in ms.audioTracks) {
                    [at setState:RTCTrackStateEnded];
                }
                [ms removeAudioTrack:ms.audioTracks[0]];
                RTCPeerConnection *peerConnection = [_connectionDic objectForKey:userId];
                [peerConnection removeStream:ms];
            }
        }];
        
        [_remoteStreams removeObjectForKey:userId];
    }
}

/***********************************************************************************/
// test nitification
- (void)addNoticeObserver
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(handleInterruptionNotification:)
                   name:AVAudioSessionInterruptionNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleRouteChangeNotification:)
                   name:AVAudioSessionRouteChangeNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleMediaServicesWereLost:)
                   name:AVAudioSessionMediaServicesWereLostNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleMediaServicesWereReset:)
                   name:AVAudioSessionMediaServicesWereResetNotification
                 object:nil];
}

- (void)handleInterruptionNotification:(NSNotification *)notification {
    NSNumber* typeNumber =
    notification.userInfo[AVAudioSessionInterruptionTypeKey];
    AVAudioSessionInterruptionType type =
    (AVAudioSessionInterruptionType)typeNumber.unsignedIntegerValue;
    switch (type) {
        case AVAudioSessionInterruptionTypeBegan:
            NSLog(@"Audio session interruption began.");
            break;
        case AVAudioSessionInterruptionTypeEnded: {
            NSLog(@"Audio session interruption ended.");
            NSNumber *optionsNumber =
            notification.userInfo[AVAudioSessionInterruptionOptionKey];
            AVAudioSessionInterruptionOptions options =
            optionsNumber.unsignedIntegerValue;
            BOOL shouldResume =
            options & AVAudioSessionInterruptionOptionShouldResume;
            break;
        }
    }
}

- (void)handleRouteChangeNotification:(NSNotification *)notification {
    // Get reason for current route change.
    NSNumber* reasonNumber =
    notification.userInfo[AVAudioSessionRouteChangeReasonKey];
    AVAudioSessionRouteChangeReason reason =
    (AVAudioSessionRouteChangeReason)reasonNumber.unsignedIntegerValue;
    NSLog(@"Audio route changed:");
    switch (reason) {
        case AVAudioSessionRouteChangeReasonUnknown:
            NSLog(@"Audio route changed: ReasonUnknown");
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"Audio route changed: NewDeviceAvailable");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"Audio route changed: OldDeviceUnavailable");
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"Audio route changed: CategoryChange to :%@",
                   [AVAudioSession sharedInstance].category);
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@"Audio route changed: Override");
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@"Audio route changed: WakeFromSleep");
            break;
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@"Audio route changed: NoSuitableRouteForCategory");
            break;
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
            NSLog(@"Audio route changed: RouteConfigurationChange");
            break;
    }
    AVAudioSessionRouteDescription* previousRoute =
    notification.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    // Log previous route configuration.
    NSLog(@"Previous route: %@\nCurrent route:%@",
           previousRoute, [AVAudioSession sharedInstance].currentRoute);
}

- (void)handleMediaServicesWereLost:(NSNotification *)notification {
    NSLog(@"Media services were lost.");
    //BOOL shouldActivate = NO;
    //AVAudioSessionSetActiveOptions options = shouldActivate ?
    //0 : AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation;
    //NSError *error = nil;
    //if ([[AVAudioSession sharedInstance] setActive:shouldActivate
    //                withOptions:options
    //                      error:&error]) {
    //
    //}
}

- (void)handleMediaServicesWereReset:(NSNotification *)notification {
    NSLog(@"Media services were reset.");
}
/*******************************************************************************/

/**
 *  创建本地流，并且把本地流回调出去
 */
- (void)createLocalStream
{
    _localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];
    //音频
    RTCAudioTrack *audioTrack = [_factory audioTrackWithID:@"ARDAMSa0"];
    [_localStream addAudioTrack:audioTrack];
    
    if (_useVideo == NO)
    {
        return;
    }
    //视频
    NSArray *deviceArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *device = [deviceArray lastObject];
    //检测摄像头权限
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        NSLog(@"相机访问受限");
        if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
        {
            [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
        }
    }
    else
    {
        if (device)
        {
            RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:device.localizedName];
            RTCVideoSource *videoSource = [_factory videoSourceWithCapturer:capturer constraints:[self localVideoConstraints]];
            RTCVideoTrack *videoTrack = [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
            
            [_localStream addVideoTrack:videoTrack];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
                {
                    [_delegate webRTCHelper:self setLocalStream:_localStream userId:_myId];
                }
            });
        }
        else
        {
            NSLog(@"该设备不能打开摄像头");
            if ([_delegate respondsToSelector:@selector(webRTCHelper:setLocalStream:userId:)])
            {
                [_delegate webRTCHelper:self setLocalStream:nil userId:_myId];
            }
        }
    }
}
/**
 *  视频的相关约束
 */
- (RTCMediaConstraints *)localVideoConstraints
{
    RTCPair *maxWidth = [[RTCPair alloc] initWithKey:@"maxWidth" value:@"640"];
    RTCPair *minWidth = [[RTCPair alloc] initWithKey:@"minWidth" value:@"640"];
    
    RTCPair *maxHeight = [[RTCPair alloc] initWithKey:@"maxHeight" value:@"480"];
    RTCPair *minHeight = [[RTCPair alloc] initWithKey:@"minHeight" value:@"480"];
    
    RTCPair *minFrameRate = [[RTCPair alloc] initWithKey:@"minFrameRate" value:@"15"];
    
    NSArray *mandatory = @[maxWidth, minWidth, maxHeight, minHeight, minFrameRate];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatory optionalConstraints:nil];
    return constraints;
}
/**
 *  为所有连接创建offer
 */
- (void)createOffers
{
    //给每一个点对点连接，都去创建offer
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        _currentId = key;
        _role = RoleCaller;
        [obj createOfferWithDelegate:self constraints:[self offerOranswerConstraint]];
    }];
}
/**
 *  为所有连接添加流
 */
- (void)addStreams
{
    //给每一个点对点连接，都加上本地流
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        if (!_localStream)
        {
            [self createLocalStream];
        }
        [obj addStream:_localStream];
    }];
}
/**
 *  创建所有连接
 */
- (void)createPeerConnections
{
    //从我们的连接数组里快速遍历
    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        //根据连接ID去初始化 RTCPeerConnection 连接对象
        RTCPeerConnection *connection = [self createPeerConnection:obj];
        
        //设置这个ID对应的 RTCPeerConnection对象
        [_connectionDic setObject:connection forKey:obj];
    }];
}
/**
 *  创建点对点连接
 *
 *  @param connectionId <#connectionId description#>
 *
 *  @return <#return value description#>
 */
- (RTCPeerConnection *)createPeerConnection:(NSString *)connectionId
{
    //如果点对点工厂为空
    if (!_factory)
    {
        //先初始化工厂
        [RTCPeerConnectionFactory initializeSSL];
        _factory = [[RTCPeerConnectionFactory alloc] init];
    }
    
    //得到ICEServer
    if (!ICEServers)
    {
        ICEServers = [NSMutableArray array];
        //[ICEServers addObject:[self defaultSTUNServer]];
        //[ICEServers addObject:[self defaultSTUNServer:RTCTURNServerURL]];
        for (NSObject *object in _iceServers)
        {
            NSString *stunURL = (NSString *)object;
            if (!stunURL) {
                NSLog(@"[createPeerConnection] stunURL is nil !");
                return nil;
            }
            
            NSString *un = @"";
            NSString *pw = @"";
            if ([stunURL containsString:@"turn"]) {
                NSArray *temp = [stunURL componentsSeparatedByString:@"|"];
                if (temp.count == 3) {
                    stunURL = temp[0];
                    un = temp[1];
                    pw = temp[2];
                }
            }
#ifdef DEBUG
           NSLog(@"[createPeerConnection] stunURL is : %@",stunURL);
#endif
            
            //stunURL = [stunURL stringByAppendingString:(NSString *)object];
            NSURL *defaultSTUNServerURL = [NSURL URLWithString:stunURL];
            RTCICEServer *iceServer = [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL username:un password:pw];
            
            [ICEServers addObject:iceServer];
        }
    }
    
    //用工厂来创建连接
    RTCPeerConnection *connection = [_factory peerConnectionWithICEServers:ICEServers constraints:[self peerConnectionConstraints] delegate:self];
    return connection;
}


//初始化STUN Server （ICE Server）
- (RTCICEServer *)defaultSTUNServer {
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:RTCSTUNServerURL];
    return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@""
                                    password:@""];
}

- (RTCICEServer *)defaultSTUNServer:(NSString *)stunURL {
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:stunURL];
    return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@"bszk"
                                    password:@"123456"];
}

/**
 *  peerConnection约束
 *
 *  @return <#return value description#>
 */
- (RTCMediaConstraints *)peerConnectionConstraints
{
    //RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:@[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]]];
    NSMutableArray *array = [NSMutableArray array];
    RTCPair *receiveAudio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
    [array addObject:receiveAudio];

    NSString *video = _useVideo ? @"true":@"false";
    RTCPair *receiveVideo = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video];
    [array addObject:receiveVideo];

    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:array optionalConstraints:@[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]]];
    
    return constraints;
}
/**
 *  设置offer/answer的约束
 */
- (RTCMediaConstraints *)offerOranswerConstraint
{
    NSMutableArray *array = [NSMutableArray array];
    RTCPair *receiveAudio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
    [array addObject:receiveAudio];
    
    //NSString *video = @"true";
    NSString *video = _useVideo ? @"true":@"false";
    RTCPair *receiveVideo = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video];
    [array addObject:receiveVideo];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:array optionalConstraints:nil];
    return constraints;
}

#pragma mark--RTCSessionDescriptionDelegate
// Called when creating a session.
//创建了一个SDP就会被调用，（只能创建本地的）
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
    NSLog(@"%@",sdp.type);
#endif
    
    //设置本地的SDP
    [peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
    
}

// Called when setting a local or remote description.
//当一个远程或者本地的SDP被设置就会调用
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
#endif

    _currentId = [self getKeyFromConnectionDic : peerConnection];
    
    //判断，当前连接状态为，收到了远程点发来的offer，这个是进入房间的时候，尚且没人，来人就调到这里
    if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer)
    {
        //创建一个answer,会把自己的SDP信息返回出去
        [peerConnection createAnswerWithDelegate:self constraints:[self offerOranswerConstraint]];
    }
    //判断连接状态为本地发送offer
    else if (peerConnection.signalingState == RTCSignalingHaveLocalOffer)
    {
        if (_role == RoleCallee)
        {
            NSDictionary *dic = @{@"eventName": @"__answer", @"data": @{@"sdp": @{@"type": @"answer", @"sdp": peerConnection.localDescription.description}, @"socketId": _currentId}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
        //发送者,发送自己的offer
        else if(_role == RoleCaller)
        {
            NSDictionary *dic = @{@"eventName": @"__offer", @"data": @{@"sdp": @{@"type": @"offer", @"sdp": peerConnection.localDescription.description}, @"socketId": _currentId}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
    }
    else if (peerConnection.signalingState == RTCSignalingStable)
    {
        if (_role == RoleCallee)
        {
            NSDictionary *dic = @{@"eventName": @"__answer", @"data": @{@"sdp": @{@"type": @"answer", @"sdp": peerConnection.localDescription.description}, @"socketId": _currentId}};
            NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
            [_socket send:data];
        }
    }
}
#pragma mark--RTCPeerConnectionDelegate
// Triggered when the SignalingState changed.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
    NSLog(@"%d", stateChanged);
#endif

    if (stateChanged == RTCSignalingClosed) {
        //[self setAudioSessionActive:1];
    }
}

- (void)setAudioSessionActive:(int) active {
    dispatch_async(dispatch_get_main_queue(), ^{
        UnitySetAudioSessionActive(active);
        [self getCurrentCategory:@"SignalingClosed"];
    });
}

// Triggered when media is received on a new stream from remote peer.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
#endif
    
    NSString *uid = [self getKeyFromConnectionDic : peerConnection];
    [_remoteStreams setObject:stream forKey:uid];
    
    if (_useVideo == NO) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_delegate respondsToSelector:@selector(webRTCHelper:addRemoteStream:userId:)])
        {
            [_delegate webRTCHelper:self addRemoteStream:stream userId:uid];
        }
    });
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream
{
    NSLog(@"%s",__func__);
}

- (NSString *)getKeyFromConnectionDic:(RTCPeerConnection *)peerConnection
{
    //find socketid by pc
    static NSString *socketId;
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        if ([obj isEqual:peerConnection])
        {
            //NSLog(@"%@",key);
            socketId = key;
        }
    }];
    return socketId;
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection
{
    NSLog(@"%s",__func__);
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
    NSLog(@"%d", newState);
#endif
    
    NSString *uId = [self getKeyFromConnectionDic : peerConnection];
    
    if (newState == RTCICEConnectionConnected){
        //[self getCurrentCategory:@"Connected1"];
        [self enableSpeaker:YES];
        //[self getCurrentCategory:@"Connected2"];
    }
    else if (newState == RTCICEConnectionDisconnected)
    {
        
    }
    else if (newState == RTCICEConnectionClosed || newState == RTCICEConnectionFailed){
        
        //[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
        //[self getCurrentCategory:@"Closed"];
        
        if ([_delegate respondsToSelector:@selector(webRTCHelper:noticePCClosed:)])
        {
            [_delegate webRTCHelper:self noticePCClosed:uId];
        }
    }
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState
{
    //NSLog(@"%s",__func__);
    //NSLog(@"%d", newState);
}

// New Ice candidate have been found.
//创建peerConnection之后，从server得到响应后调用，得到ICE 候选地址
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate
{
#ifdef DEBUG
    NSLog(@"%s",__func__);
#endif
    
    _currentId = [self getKeyFromConnectionDic : peerConnection];
    
    NSDictionary *dic = @{@"eventName": @"__ice_candidate", @"data": @{@"id":candidate.sdpMid,@"label": [NSNumber numberWithInteger:candidate.sdpMLineIndex], @"candidate": candidate.sdp, @"socketId": _currentId}};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    [_socket send:data];
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel

{
    //NSLog(@"%s",__func__);
}

/***********************************************************************************************************************/
//声音，话筒，扬声器开关
/***********************************************************************************************************************/
- (void)activeLocalStream:(BOOL)active
{
    [self activeStream:_localStream active:active];
}

- (void)activeRemoteStream:(BOOL)active
{
    if (!_remoteStreams) {
        return;
    }
#ifdef DEBUG
    NSLog(@"_remoteStreams count = %lu",(unsigned long)_remoteStreams.count);
#endif
    
    [_remoteStreams enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, RTCMediaStream *ms, BOOL * _Nonnull stop) {
        if (ms) {
            [self activeStream:ms active:active];
        }
    }];
}

- (void)activeStream:(RTCMediaStream *)ms active:(BOOL)active
{
    if (ms == nil) {
        return;
    }
    
    for (RTCVideoTrack * vt in ms.videoTracks) {
        if (active == [vt isEnabled]) {
            return;
        }
        
        [vt setEnabled:active];
    }
    for (RTCAudioTrack * at in ms.audioTracks) {
        if (active == [at isEnabled]) {
            return;
        }
        
        [at setEnabled:active];
    }
}

- (void)muteAudioIn {
    NSLog(@"audio muted");
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *peerConnection, BOOL * _Nonnull stop) {
        RTCMediaStream *localStream = peerConnection.localStreams[0];
        self.defaultAudioTrack = localStream.audioTracks[0];
        [localStream removeAudioTrack:localStream.audioTracks[0]];
        [peerConnection removeStream:localStream];
        [peerConnection addStream:localStream];
    }];
}

- (void)unmuteAudioIn {
    NSLog(@"audio unmuted");
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *peerConnection, BOOL * _Nonnull stop) {
        RTCMediaStream* localStream = peerConnection.localStreams[0];
        [localStream addAudioTrack:self.defaultAudioTrack];
        [peerConnection removeStream:localStream];
        [peerConnection addStream:localStream];
        //if (_isSpeakerEnabled) [self enableSpeaker];
    }];
}

- (void)enableSpeaker:(BOOL)enable {
    if (_isSpeakerEnabled == enable) {
        return;
    }
    
    if (_isAudioRoutInited) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification
                                object:nil];
        _isAudioRoutInited = NO;
    }
    if (enable) {
        //[[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];

        _isSpeakerEnabled = YES;
    }
    else{
        
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        
        _isSpeakerEnabled = NO;
    }
    
}

- (void)audioRouteInitialize {
    if (_isAudioRoutInited == YES) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                        selector:@selector(routeChange:)
                                        name:AVAudioSessionRouteChangeNotification
                                        object:nil];
    
    _isAudioRoutInited = YES;
    NSLog(@"AudioRoute plugin initialized");
}

- (void)routeChange:(NSNotification*)notification {
    if (_isAudioRoutInited == NO) {
        return;
    }
    
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonCategoryChange: {
            
            NSError* error;
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
            _isSpeakerEnabled = YES;
        }
        break;
            
        default:
            break;
    }
}

- (void) getCurrentCategory:(NSString *) code{
    NSString *category = [[AVAudioSession sharedInstance] category];
    NSLog(@"code = %@;CurrentCategory = %@",code,category);
}

-(void)setVolume:(float)value{
    
    MPVolumeView *volumeView = [[MPVolumeView alloc]init];
    
    volumeView.showsRouteButton = NO;
    //默认YES，这里为了突出，故意设置一遍
    volumeView.showsVolumeSlider = YES;
    
    [volumeView sizeToFit];
    [volumeView setFrame:CGRectMake(-1000, -1000, 10, 10)];
    [volumeView userActivity];
    
    UISlider* volumeSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([[view.class description] isEqualToString:@"MPVolumeSlider"]){
            volumeSlider = (UISlider*)view;
            break;
        }
    }
    
    // retrieve system volume
    float systemVolume = volumeSlider.value;
    
    // change system volume, the value is between 0.0f and 1.0f
    [volumeSlider setValue:value animated:NO];
    
    // send UI control event to make the change effect right now.
    [volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
}

/***********************************************************************************************************************/
//心跳，断线重连
/***********************************************************************************************************************/
- (void)initHeartCheck:(SRWebSocket *)socket {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                        selector:@selector(reconnect:)
                                            name:WebsocketReconnectNotification
                                        object:nil];
    
    heartCheck = [[HeartCheck alloc]initWithWebsocket:_socket];
    [heartCheck start];
}

- (void)reconnect:(NSNotification*)notification {
    [self destroyHeartCheck];
    if (_socket) {
        [_socket closeWithCode:1006 reason:@""];
        _socket = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                        name:WebsocketReconnectNotification
                                        object:nil];
    
    //主动断开，无需重连
    if (!_roomConnectionWorking) {
        return;
    }
    
    [self connectServer];
}

//销毁心跳
- (void)destroyHeartCheck
{
    if (heartCheck) {
        [heartCheck stop];
        heartCheck = nil;
    }
}

@end
