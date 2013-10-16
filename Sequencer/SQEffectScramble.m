//
//  SQEffectScramble.m
//  Sequencer
//
//  Created by Jon Como on 10/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQEffectScramble.h"

#import "SQVideoComposer.h"

@implementation SQEffectScramble

-(void)renderEffectCompletion:(void (^)(SRClip *output))block
{
    NSDictionary *info = [self scrambledCompositionFromClip:self.clip];
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [[SQVideoComposer new] exportCompositionInfo:info toURL:outputURL withPreset:AVAssetExportPreset640x480 progress:nil withCompletionHandler:^(NSError *error) {
        
        SRClip *newClip = [[SRClip alloc] initWithURL:outputURL];
        
        [newClip generateThumbnailsCompletion:^(NSError *error) {
            if (block) block(newClip);
        }];
    }];
}

-(NSDictionary *)scrambledCompositionFromClip:(SRClip *)clip
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:clip.URL options:nil];
    
    AVMutableComposition *scrambled = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *videoTrack = [scrambled addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [scrambled addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableVideoComposition *mutableVideoComposition;
    NSMutableArray *instructions = [NSMutableArray array];
    
    CMTime startTime = kCMTimeZero;
    
    if (!mutableVideoComposition){
        mutableVideoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    }
    
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    AVAssetTrack *clipVideoTrack = videoTracks.count != 0 ? videoTracks[0] : nil;
    AVAssetTrack *clipAudioTrack = audioTracks.count != 0 ? audioTracks[0] : nil;
    
    for (int i = 0; i<15; i++)
    {
        float randFloat = arc4random()%(int)(CMTimeGetSeconds(asset.duration) * 100)/100.0f;
        CMTime randomTime = CMTimeMake(randFloat, asset.duration.timescale);
        
        CMTimeRange randomRange = CMTimeRangeMake(randomTime, CMTimeAdd(randomTime, CMTimeMake(0.1, asset.duration.timescale)));
        
        if (clipVideoTrack)
            [videoTrack insertTimeRange:randomRange ofTrack:clipVideoTrack atTime:startTime error:nil];
        
        if (clipAudioTrack)
            [audioTrack insertTimeRange:randomRange ofTrack:clipAudioTrack atTime:startTime error:nil];
        
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        [layerInstruction setTransform:videoTrack.preferredTransform atTime:startTime];
        
        instruction.layerInstructions = @[layerInstruction];
        instruction.timeRange = CMTimeRangeMake(startTime, asset.duration);
        
        [instructions addObject:instruction];
        
        startTime = CMTimeAdd(startTime, randomRange.duration);
    }
    
    mutableVideoComposition.instructions = instructions;
    
    if (!scrambled || !mutableVideoComposition) return nil;
    
    return @{SQVideoComposerComposition : scrambled, SQVideoComposerVideoComposition : mutableVideoComposition, SQVideoComposerDuration : [NSValue valueWithCMTime:startTime]};
}

@end