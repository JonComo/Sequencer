//
//  SQVideoComposer.m
//  Sequencer
//
//  Created by Jon Como on 9/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQVideoComposer.h"

#import "SRClip.h"

@implementation SQVideoComposer

+ (void)exportClips:(NSArray *)clips toURL:(NSURL *)outputFile withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))block
{
    NSArray *assets = [SQVideoComposer compositionFromClips:clips];
    AVComposition *composition = assets[0];
    AVVideoComposition *videoComposition = assets[1];
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.videoComposition = videoComposition;
    exporter.outputURL = outputFile;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
            case AVAssetExportSessionStatusCancelled:
            case AVAssetExportSessionStatusCompleted:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(nil);
                });
            } break;
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block([NSError errorWithDomain:@"Unknown export error" code:100 userInfo:nil]);
                });
            } break;
        }
        
    }];
}

+(NSArray *)compositionFromClips:(NSArray *)clips
{
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableVideoComposition *mutableVideoComposition;
    NSMutableArray *instructions = [NSMutableArray array];
    
    CMTime startTime = kCMTimeZero;
    CGSize exportSize = CGSizeMake(0, 0); //find largest video track
    
    for (SRClip *clip in clips)
    {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:clip.URL options:nil];
        
        if (!mutableVideoComposition){
            mutableVideoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:asset];
        }
        
        NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        
        AVAssetTrack *clipVideoTrack = videoTracks.count != 0 ? videoTracks[0] : nil;
        AVAssetTrack *clipAudioTrack = audioTracks.count != 0 ? audioTracks[0] : nil;
        
        if (clipVideoTrack)
            [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:clipVideoTrack atTime:startTime error:nil];
        
        if (clipAudioTrack)
            [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:clipAudioTrack atTime:startTime error:nil];
        
        if (videoTrack.naturalSize.width > exportSize.width) exportSize.width = videoTrack.naturalSize.width;
        if (videoTrack.naturalSize.height > exportSize.height) exportSize.height = videoTrack.naturalSize.height;
        
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        CMTimeRange range = CMTimeRangeMake(startTime, asset.duration);
        
        [layerInstruction setTransform:videoTrack.preferredTransform atTime:startTime];
        
        if (clip.modifyLayerInstruction)
            clip.modifyLayerInstruction(layerInstruction, range);
        
        instruction.layerInstructions = @[layerInstruction];
        instruction.timeRange = range;
        
        [instructions addObject:instruction];
        
        startTime = CMTimeAdd(startTime, asset.duration);
    }
    
    mutableVideoComposition.instructions = instructions;
    
    return @[composition, mutableVideoComposition];
}

@end