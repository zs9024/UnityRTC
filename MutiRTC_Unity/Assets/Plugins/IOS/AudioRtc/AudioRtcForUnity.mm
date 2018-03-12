//
//  AudioRtcForUnity.mm
//  Unity-iPhone
//
//  Created by waking on 17/3/20.
//
//  the medium between webrtc and unity

#import <Foundation/Foundation.h>
#import "AudioRtcForUnity.h"
#import "WebRTCHelper.h"
#import "UnityAppController.h"

#define KScreenWidth [UIScreen mainScreen].bounds.size.width
#define KScreenHeight [UIScreen mainScreen].bounds.size.height

#define KVedioWidth KScreenWidth/3.0
#define KVedioHeight KVedioWidth*320/240

@interface AudioRtcForUnity ()<WebRTCHelperDelegate>
{
    UIView *rtcView;
    
    //本地摄像头追踪
    RTCVideoTrack *_localVideoTrack;
    //远程的视频追踪
    NSMutableDictionary *_remoteVideoTracks;
    
    //
    NSMutableDictionary *_remoteVideoViews;
    
    BOOL isConnected;
    BOOL isJoinedRoom;
    BOOL leaveAbnormaly;
}
@end

static NSString *gameObjectName = nil;

#if defined(__cplusplus)
extern "C"{
#endif
    extern void UnitySendMessage(const char *, const char *, const char *);
#if defined(__cplusplus)
}
#endif

@implementation AudioRtcForUnity

//override super init
- (id)init
{
    NSLog(@"AudioRtcForUnity init...");
    if (self = [super init] )
    {
        _remoteVideoTracks = [NSMutableDictionary dictionary];
        [WebRTCHelper sharedInstance].delegate = self;
        
        [self setRtcView];
        _videoEnable = NO;
        
        self.isAudioMute = NO;
        self.isVideoMute = NO;
    }
    
    return self;
}

/*
/u3d sendmessage
*/
+ (void)sendU3dMessage:(NSString *)messageName param:(NSDictionary *)dict
{
    NSString *param = @"";
    if ( nil != dict ) {
        for (NSString *key in dict)
        {
            if ([param length] == 0)
            {
                param = [param stringByAppendingFormat:@"%@=%@", key, [dict valueForKey:key]];
            }
            else
            {
                param = [param stringByAppendingFormat:@"&%@=%@", key, [dict valueForKey:key]];
            }
        }
    }
    if (!gameObjectName) {
        gameObjectName = @"Main Camera";
    }
    UnitySendMessage([gameObjectName UTF8String], [messageName UTF8String], [param UTF8String]);
}

/**
 *  设置接收 UnitySendMessage 的 GameObject
 *
 *  @param GameObjectName GameObject 名称
 */
-(void)setListenerGameObject:(NSString *)GameObjectName{
    gameObjectName = GameObjectName;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
/webrtc delegate and server communication
*/

//连接
- (void)connectAction
{
    //[[WebRTCHelper sharedInstance]connectServer:@"172.16.130.6" port:@"3000" room:@"100"];
}

//连接
- (void)connectAction:(NSString *)host setPort:(NSString *)port setIceServers:(NSArray *)iceServers
{
    [[WebRTCHelper sharedInstance]connectServer:host port:port iceServers:iceServers];
}

//
- (void)joinRoomAction:(NSString *)room 
{
    if (!isConnected && isJoinedRoom) {
        return;
    }
    
    [[WebRTCHelper sharedInstance] joinRoom:room enableVideo:_videoEnable];
}

//断开连接
- (void)disConnectAction
{
    if(!isJoinedRoom && !leaveAbnormaly){
        return;
    }

    [[WebRTCHelper sharedInstance] exitRoom];
    isJoinedRoom = NO;
    isConnected = NO;
    leaveAbnormaly = NO;
}

- (void)mutMicrophone:(BOOL)active
{
    [[WebRTCHelper sharedInstance] activeLocalStream:active];
}

- (void)mutEarphone:(BOOL)active
{
    [[WebRTCHelper sharedInstance] activeRemoteStream:active];
}

- (void)mutSpeaker:(BOOL)active
{
    [[WebRTCHelper sharedInstance] enableSpeaker:active];
}

-(void)setRtcView
{
    UIWindow *window= [[UIApplication sharedApplication] keyWindow];//获取主窗口
    rtcView=[window.subviews objectAtIndex:0];                 //获取根view
}

- (void)webRTCHelper:(WebRTCHelper *)webRTChelper setLocalStream:(RTCMediaStream *)stream userId:(NSString *)userId
{
    RTCEAGLVideoView *localVideoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, KVedioWidth, KVedioHeight)];
    //标记本地的摄像头
    localVideoView.tag = 100;
    _localVideoTrack = [stream.videoTracks lastObject];
    [_localVideoTrack addRenderer:localVideoView];
    
    [rtcView addSubview:localVideoView];
    
    NSLog(@"setLocalStream");
}
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper addRemoteStream:(RTCMediaStream *)stream userId:(NSString *)userId
{
    //缓存起来
    [_remoteVideoTracks setObject:[stream.videoTracks lastObject] forKey:userId];
    [self _refreshRemoteView];
    NSLog(@"addRemoteStream");
    
}

- (void)webRTCHelper:(WebRTCHelper *)webRTChelper closeWithUserId:(NSString *)userId
{
    //移除对方视频追踪
    [self removeRemoteTrack:userId];
    [self _refreshRemoteView];
    NSLog(@"closeWithUserId");
}

- (void)_refreshRemoteView
{
    for (RTCEAGLVideoView *videoView in rtcView.subviews) {
        //本地的视频View和关闭按钮不做处理
        if (videoView.tag == 100 ||videoView.tag == 123) {
            continue;
        }
        //其他的移除
        [videoView removeFromSuperview];
    }
    __block int column = 1;
    __block int row = 0;
    //再去添加
    [_remoteVideoTracks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, RTCVideoTrack *remoteTrack, BOOL * _Nonnull stop) {
        
        RTCEAGLVideoView *remoteVideoView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(column * KVedioWidth, 0, KVedioWidth, KVedioHeight)];
        [remoteTrack addRenderer:remoteVideoView];
        [rtcView addSubview:remoteVideoView];
        
        //把view存入字典
        if (!_remoteVideoViews) {
            _remoteVideoViews = [NSMutableDictionary dictionary];
        }
        if (![_remoteVideoViews objectForKey:key]) {
            [_remoteVideoViews setObject:remoteVideoView forKey:key];
        }
        
        //列加1
        column++;
        //一行多余3个在起一行
        if (column > 3) {
            row++;
            column = 0;
        }
    }];
}

- (void)removeLocalTrack
{
    if (!_localVideoTrack) {
        return;
    }
    
    for (RTCEAGLVideoView *videoView in rtcView.subviews) {
        if (videoView.tag == 100 ||videoView.tag == 123) {
            [_localVideoTrack removeRenderer:videoView];
            _localVideoTrack = nil;
            [videoView removeFromSuperview];
            [videoView renderFrame:nil];
        }
    }
}

- (void)removeRemoteTrack:(NSString *) userId
{
    [_remoteVideoTracks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, RTCVideoTrack *remoteTrack, BOOL * _Nonnull stop) {
        if ([userId isEqualToString:key]) {
            RTCEAGLVideoView *remoteView = [_remoteVideoViews objectForKey:key];
            if (remoteTrack) {
                [remoteTrack removeRenderer:remoteView];
                remoteTrack = nil;
            }
            
            if (remoteView) {
                [remoteView removeFromSuperview];
                [remoteView renderFrame:nil];
            }
        }
    }];
    
    [_remoteVideoTracks removeObjectForKey:userId];
    [_remoteVideoViews removeObjectForKey:userId];
}

//////////////////////////////////////////////////////////////////////////////////////////
//notice u3d server connected and sdk inited
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeConnected:(NSString *)msg
{
    NSLog(@"noticeConnected,msg is :%@",msg);
    isConnected = YES;
    [AudioRtcForUnity sendU3dMessage:@"OnRtcInitSdk" param:@{@"userId":msg}];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeJoinedRoom:(NSArray *)peersId myId:(NSString *)myId
{
    NSLog(@"noticeJoinedRoom,myId is :%@",myId);
    isJoinedRoom = YES;
    NSDictionary *ret = [NSDictionary dictionaryWithObjectsAndKeys:
                         myId, @"myId",
                         peersId, @"peers", nil];
    NSLog(@"reveive JoinedRoom Data === %@",ret);
    [AudioRtcForUnity sendU3dMessage:@"OnRtcJoinRoom" param:ret];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeNewPeerJoinRomm:(NSString *)userId
{
    NSLog(@"noticeNewPeerJoinRomm,userId is :%@",userId);
    //[AudioRtcForUnity sendU3dMessage:@"OnRtcInitSdk" param:@{@"userId":userId}];
}

- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticeDisconnectRoom:(NSString *)msg;
{
    NSLog(@"noticeDisconnectRoom...");
    //异常离开
    if (isJoinedRoom) {
			leaveAbnormaly = true;
            [[WebRTCHelper sharedInstance] closePeerConnections];
			isJoinedRoom = false;
	        isConnected = false;
    }
    else{
        [self removeLocalTrack];
    }
    
    [AudioRtcForUnity sendU3dMessage:@"OnRtcLeaveRoom" param:@{@"userId":@""}];
}

//端对端peerconnection关闭
- (void)webRTCHelper:(WebRTCHelper *)webRTChelper noticePCClosed:(NSString *)userId
{
    NSLog(@"noticePCClosed,userId is :%@",userId);
    
}

@end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static AudioRtcForUnity* audioRtc = nil;

// Converts C style string to NSString
NSString* CreateNSString (const char* string)
{
    if (string)
        return [NSString stringWithUTF8String: string];
    else
        return [NSString stringWithUTF8String: ""];
}

// Helper method to create C string copy
char* MakeStringCopy (const char* string)
{
    if (string == NULL)
        return NULL;
    
    char* res = (char*)malloc(strlen(string) + 1);
    strcpy(res, string);
    return res;
}

/*!
 * @brief 把格式化的JSON字符串转换成字典
 * @param jsonString JSON格式的字符串
 * @return 返回字典
 */
NSDictionary* CreateDictionaryWithJsonString(const char* jsonString)
{
    if (jsonString == NULL)
    {
        NSLog(@"jsonString is NULL");
        return nil;
    }
    
    NSString* str = CreateNSString(jsonString);
    NSData* jsonData = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSError* err;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&err];
    
    if (err)
    {
        NSLog(@"json parse failed：%@",err);
        return nil;
    }
    
    return dict;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#if defined (__cplusplus)
extern "C" {
#endif

    //initialize audio sdk
    bool rtcInitSDK(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity initSDK...");
        
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSString* host = [dict objectForKey:@"host"];
        NSString* port = [dict objectForKey:@"port"];
        NSArray* iceServers = [dict objectForKey:@"iceServers"];
        
        for (int i = 0 ; i < [iceServers count]; i++) {
            NSLog(@"遍历iceServers: %zi-->%@",i,[iceServers objectAtIndex:i]);
        }
        
        if (audioRtc == nil){
            audioRtc = [[AudioRtcForUnity alloc]init];
        }
        
        //set the callback gameobject in u3d
        [audioRtc setListenerGameObject:@"PlatformSDK"];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            //NSLog(@"mainThread----%@",[NSThread mainThread]);
            //NSLog(@"currentThread----%@",[NSThread currentThread]);
            [audioRtc connectAction:host setPort:port setIceServers:iceServers];
        });
        
        return true;
    }
    
    //create a room
    bool rtcCreateRoom(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity createRoom...");
        
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSString* room = [dict objectForKey:@"room"];
        if (room == nil || [room isEqualToString:@""]) {
            room = @"100";
        }
        
        if (audioRtc == nil) {
            audioRtc = [[AudioRtcForUnity alloc]init];
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [audioRtc joinRoomAction:room];
        });
		
        return true;
    }
    
    //join a room
    bool rtcJoinRoom(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity joinRoom...");
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSString* room = [dict objectForKey:@"room"];
        if (room == nil || [room isEqualToString:@""]) {
            room = @"100";
        }
        
        if (audioRtc == nil) {
            audioRtc = [[AudioRtcForUnity alloc]init];
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [audioRtc joinRoomAction:room];
        });
        
        return true;
    }
    
    //leave a room
    bool rtcLeaveRoom(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity leaveRoom...");
        if (audioRtc == nil)
            audioRtc = [[AudioRtcForUnity alloc]init];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [audioRtc disConnectAction];
        });
        
        return true;
    }
    
    //destroy the room
    bool rtcDestroyRoom(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity destroyRoom...");
        if (audioRtc == nil)
            audioRtc = [[AudioRtcForUnity alloc]init];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [audioRtc disConnectAction];
        });
        
        return true;
    }
    
    //send message by webrtc datachannel--have not impl
    bool rtcSendMsg(const char *jsonString)
    {
        
        return true;
    }
    
    //activee or mute mp
    bool rtcMuteMicrophone(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity rtcMuteMicrophone...");
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSNumber *setting = [dict objectForKey:@"mute"];
        
        if (audioRtc == nil)
            audioRtc = [[AudioRtcForUnity alloc]init];
        
        BOOL active = [setting intValue] == 0 ? NO : YES;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [audioRtc mutMicrophone:active];
        });       
        
        return true;
    }
    
    //activee or mute ep
    bool rtcMuteEarPhone(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity rtcMuteEarPhone...");
        
        
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSNumber *setting = [dict objectForKey:@"mute"];
        
        if (audioRtc == nil)
            audioRtc = [[AudioRtcForUnity alloc]init];
        BOOL active = [setting intValue] == 0 ? NO : YES;
        
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
            [audioRtc mutEarphone:active];
        });
        
        return true;
    }
    
    //activee or mute Speaker
    bool rtcMuteSpeaker(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity rtcMuteSpeaker...");
        
        
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSNumber *setting = [dict objectForKey:@"mute"];
        
        if (audioRtc == nil)
            audioRtc = [[AudioRtcForUnity alloc]init];
        BOOL active = [setting intValue] == 0 ? NO : YES;
        
        [audioRtc mutSpeaker:active];
        
        return true;
    }
    
    //mute all
    bool rtcMute(const char *jsonString)
    {
        NSLog(@"AudioRtcForUnity rtcMute...");
        NSDictionary* dict = CreateDictionaryWithJsonString(jsonString);
        if (dict == nil)
            return false;
        
        NSNumber *setting = [dict objectForKey:@"mute"];
        
        if (audioRtc == nil)
            audioRtc = [[AudioRtcForUnity alloc]init];
        BOOL active = [setting intValue] == 0 ? NO : YES;
        
        [audioRtc mutMicrophone:active];
        [audioRtc mutEarphone:active];
        
        return true;
    }

#if defined (__cplusplus)
}
#endif
