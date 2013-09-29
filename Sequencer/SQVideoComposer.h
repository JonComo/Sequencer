//
//  SQVideoComposer.h
//  Sequencer
//
//  Created by Jon Como on 9/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

#define SQVideoComposerComposition @"composition"
#define SQVideoComposerVideoComposition @"videoComposition"
#define SQVideoComposerDuration @"duration"

@class SRClip;

typedef void (^ProgressHandler)(float progress);

@interface SQVideoComposer : NSObject

-(void)exportClips:(NSArray *)clips toURL:(NSURL *)outputFile withPreset:(NSString *)preset progress:(ProgressHandler)progress withCompletionHandler:(void (^)(NSError *error))block;

+(NSDictionary *)compositionFromClips:(NSArray *)clips;

+(AVMutableComposition *)timeRange:(CMTimeRange)range ofClip:(SRClip *)clip;

@end