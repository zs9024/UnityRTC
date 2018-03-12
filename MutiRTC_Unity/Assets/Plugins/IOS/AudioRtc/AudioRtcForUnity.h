//
//  AudioRtcForUnity.h
//  Unity-iPhone
//
//  Created by waking on 17/3/20.
//
//

#ifndef AudioRtcForUnity_h
#define AudioRtcForUnity_h

#import "RTCMediaStream.h"

@interface AudioRtcForUnity:NSObject
@property (assign,getter=isVideoEnable) BOOL videoEnable;

@property (assign, nonatomic) BOOL isAudioMute;
@property (assign, nonatomic) BOOL isVideoMute;

@end

#endif /* AudioRtcForUnity_h */
