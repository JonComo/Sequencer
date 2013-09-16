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

- (void)exportClips:(NSArray *)clips toURL:(NSURL *)outputFile withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))block
{
    NSArray *assets = [self compositionFromClips:clips];
    AVComposition *composition = assets[0];
    AVVideoComposition *videoComposition = assets[1];
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:composition presetName:preset];
    
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.videoComposition = videoComposition;
    exporter.outputURL = outputFile;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
            {
                block(exporter.error);
            } break;
            case AVAssetExportSessionStatusCancelled:
            case AVAssetExportSessionStatusCompleted:
            {
                block(nil);
            } break;
            default:
            {
                block([NSError errorWithDomain:@"Unknown export error" code:100 userInfo:nil]);
            } break;
        }
        
    }];
}

- (NSArray *)compositionFromClips:(NSArray *)clips
{
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    
    videoComposition.frameDuration = CMTimeMake(1,30);
    
    videoComposition.renderScale = 1.0;
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
    
    // Get only paths the user selected
    NSMutableArray *array = [NSMutableArray array];
    for(SRClip *clip in clips)
    {
        [array addObject:clip.URL];
    }
    
    NSArray *videoPathArray = array;
    
    float time = 0;
    
    for (int i = 0; i<videoPathArray.count; i++) {
        
        NSURL *sourceURL = videoPathArray[i];
        
        AVURLAsset *sourceAsset = [AVURLAsset URLAssetWithURL:sourceURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)}];
        
        NSError *error = nil;
        
        BOOL ok = NO;
        AVAssetTrack *sourceVideoTrack = [[sourceAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        
        CGSize temp = CGSizeApplyAffineTransform(sourceVideoTrack.naturalSize, sourceVideoTrack.preferredTransform);
        CGSize size = CGSizeMake(fabsf(temp.width), fabsf(temp.height));
        CGAffineTransform transform = sourceVideoTrack.preferredTransform;
        
        videoComposition.renderSize = sourceVideoTrack.naturalSize;
        if (size.width > size.height) {
            [layerInstruction setTransform:transform atTime:CMTimeMakeWithSeconds(time, 30)];
        } else {
            float s = size.width/size.height;
            
            CGAffineTransform new = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(s,s));
            
            float x = (size.height - size.width*s)/2;
            
            CGAffineTransform newer = CGAffineTransformConcat(new, CGAffineTransformMakeTranslation(x, 0));
            [layerInstruction setTransform:newer atTime:CMTimeMakeWithSeconds(time, 30)];
        }
        
        AVMutableCompositionTrack *compositionVideoTrack = [AVMutableCompositionTrack new];
        
        ok = [compositionVideoTrack insertTimeRange:sourceVideoTrack.timeRange ofTrack:sourceVideoTrack atTime:[composition duration] error:&error];
        
        
        if (!ok) {
            // Deal with the error.
            NSLog(@"something went wrong");
        }
        
        
        NSLog(@"\n source asset duration is %f \n source vid track timerange is %f %f \n composition duration is %f \n composition vid track time range is %f %f",CMTimeGetSeconds([sourceAsset duration]), CMTimeGetSeconds(sourceVideoTrack.timeRange.start),CMTimeGetSeconds(sourceVideoTrack.timeRange.duration),CMTimeGetSeconds([composition duration]), CMTimeGetSeconds(compositionVideoTrack.timeRange.start),CMTimeGetSeconds(compositionVideoTrack.timeRange.duration));
        
        time += CMTimeGetSeconds(sourceVideoTrack.timeRange.duration);
    }
    
    instruction.layerInstructions = [NSArray arrayWithObject:layerInstruction];
    instruction.timeRange = compositionVideoTrack.timeRange;
    
    videoComposition.instructions = [NSArray arrayWithObject:instruction];
    
    return @[composition, videoComposition];
}

@end