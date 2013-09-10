//
//  SQClipTimeStretch.m
//  Sequencer
//
//  Created by Jon Como on 9/10/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipTimeStretch.h"

#import "SRClip.h"

#import <AVFoundation/AVFoundation.h>

@implementation SQClipTimeStretch

- (void)stretchClip:(SRClip *)clip byPercent:(float)percent completion:(StretchCompletion)block
{
    AVURLAsset *asset = [AVURLAsset assetWithURL:clip.URL];
    
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *mutableCompositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Add video
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    [mutableCompositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoAssetTrack.timeRange.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    
    //Add audio
    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    [mutableCompositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    
    
    
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, 600);
    videoComposition.renderSize = [videoAssetTrack naturalSize];
    
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction new];
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoAssetTrack];
    
    instruction.layerInstructions = @[layerInstruction];
    videoComposition.instructions = @[instruction];
    
    
    NSURL *exportURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:mutableComposition presetName:AVAssetExportPreset640x480];
    
    NSParameterAssert(exporter != nil);
    
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.videoComposition = videoComposition;
    exporter.outputURL = exportURL;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
            {
                if (block) block(nil);
            } break;
            case AVAssetExportSessionStatusCancelled:
            case AVAssetExportSessionStatusCompleted:
            {
                
                SRClip *stretched = [[SRClip alloc] initWithURL:exportURL];
                
                [stretched generateThumbnailCompletion:^(BOOL success) {
                    if (block) block(stretched);
                }];
                
                if (block) block(stretched);
                
            } break;
            default:
            {
                if (block) block(nil);
            } break;
        }
        
    }];
}

//- (void)exportTo:(NSURL *)outputFile withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))completionHandler
//{
//    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
//    
//    videoComposition.instructions = instructions;
//    videoComposition.renderSize = outputSize;
//    
//    AVMutableVideoCompositionInstruction *lastInstruction = ((AVMutableVideoCompositionInstruction *)instructions.lastObject);
//    
//    //videoComposition.frameDuration = CMTimeAdd(lastInstruction.timeRange.start, lastInstruction.timeRange.duration);
//    
//    videoComposition.frameDuration = CMTimeMake(1, 600);
//    
//    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:composition presetName:preset];
//    NSParameterAssert(exporter != nil);
//    
//    exporter.outputFileType = AVFileTypeMPEG4;
//    exporter.videoComposition = videoComposition;
//    exporter.outputURL = outputFile;
//    
//    [exporter exportAsynchronouslyWithCompletionHandler:^{
//        
//        switch([exporter status])
//        {
//            case AVAssetExportSessionStatusFailed:
//            {
//                completionHandler(exporter.error);
//            } break;
//            case AVAssetExportSessionStatusCancelled:
//            case AVAssetExportSessionStatusCompleted:
//            {
//                completionHandler(nil);
//            } break;
//            default:
//            {
//                completionHandler([NSError errorWithDomain:@"Unknown export error" code:100 userInfo:nil]);
//            } break;
//        }
//        
//    }];
//}

@end
