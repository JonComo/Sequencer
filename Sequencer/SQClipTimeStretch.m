//
//  SQClipTimeStretch.m
//  Sequencer
//
//  Created by Jon Como on 9/10/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "SQClipTimeStretch.h"

#import "JCAudioRetime.h"
#import "JCAudioConverter.h"

#import "SRClip.h"

@implementation SQClipTimeStretch

+ (void)stretchClip:(SRClip *)clip byAmount:(float)multiple rePitch:(BOOL)rePitch completion:(StretchCompletion)block
{
    [SQClipTimeStretch extractAudioFromClip:clip completion:^(NSURL *extractedAudioURL)
    {
        [JCAudioConverter convertAudioAtURL:extractedAudioURL compress:NO completion:^(NSURL *convertedURL)
        {
            [[JCAudioRetime new] retimeAudioAtURL:convertedURL withRatio:multiple rePitch:rePitch completion:^(NSURL *outURL)
            {
                [self retimeClip:clip byAmount:multiple withAudio:outURL completion:block];
            }];
        }];
    }];
}

+(void)retimeClip:(SRClip *)clip byAmount:(float)multiple withAudio:(NSURL *)audioURL completion:(StretchCompletion)block
{
    AVURLAsset *asset = [AVURLAsset assetWithURL:clip.URL];
    AVURLAsset *assetAudio = [AVURLAsset assetWithURL:audioURL];
    
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *mutableCompositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *mutableCompositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Add video
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    [mutableCompositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoAssetTrack.timeRange.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];

    [mutableComposition scaleTimeRange:mutableCompositionVideoTrack.timeRange toDuration:assetAudio.duration];
    
    //Add audio
    AVAssetTrack *audioTrack = [[assetAudio tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    [mutableCompositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetAudio.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    
    NSURL *exportURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:mutableComposition presetName:AVAssetExportPreset640x480];
    
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.outputURL = exportURL;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(nil);
                });
            } break;
            case AVAssetExportSessionStatusCancelled:
            case AVAssetExportSessionStatusCompleted:
            {
                SRClip *stretched = [[SRClip alloc] initWithURL:exportURL];
                
                [stretched generateThumbnailsCompletion:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (block) block(stretched);
                    });
                }];
                
            } break;
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(nil);
                });
            } break;
        }
        
    }];
}

+(void)extractAudioFromClip:(SRClip *)clip completion:(void(^)(NSURL *extractedAudioURL))block
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:clip.URL options:nil];
    
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *mutableCompositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Add audio
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    if (audioTracks.count == 0){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) block(nil);
        });
        return;
    }
    
    AVAssetTrack *audioTrack = [audioTracks objectAtIndex:0];
    
    [mutableCompositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    
    
    NSURL *exportURL = [[[SRClip uniqueFileURLInDirectory:DOCUMENTS] URLByDeletingPathExtension] URLByAppendingPathExtension:@"m4a"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[exportURL path]]){
        [[NSFileManager defaultManager] removeItemAtURL:exportURL error:nil];
    }
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:mutableComposition presetName:AVAssetExportPresetAppleM4A];
    
    exporter.outputFileType = AVFileTypeAppleM4A;
    exporter.outputURL = exportURL;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(nil);
                });
            } break;
            case AVAssetExportSessionStatusCancelled:
            case AVAssetExportSessionStatusCompleted:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(exportURL);
                });
            } break;
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(nil);
                });
            } break;
        }
        
    }];
}

@end
