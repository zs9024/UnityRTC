//
//  AVAudioSession+AddAction.m
//  Unity-iPhone
//
//  Created by waking on 17/5/4.
//
//

#import <Foundation/Foundation.h>
#import "AVAudioSession+AddAction.h"


@implementation AVAudioSession (AddAction)


- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError * _Nullable __autoreleasing *)outError {
    NSLog(@"AVAudioSession+AddAction...");
    return YES;
}


@end
