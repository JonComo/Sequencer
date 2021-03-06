//
// Copyright (c) 2013 Carson McDonald
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//

#import "AVAssetStitcher.h"

#import "SRClip.h"

@implementation AVAssetStitcher
{
    CGSize outputSize;
    
    AVMutableCompositionTrack *compositionVideoTrack;
    AVMutableCompositionTrack *compositionAudioTrack;
    
    NSMutableArray *instructions;
}

- (id)initWithOutputSize:(CGSize)outSize
{
    self = [super init];
    if (self != nil)
    {
        outputSize = outSize;
        
        _composition = [AVMutableComposition composition];
        compositionVideoTrack = [_composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        compositionAudioTrack = [_composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        instructions = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addClip:(SRClip *)clip withTransform:(CGAffineTransform (^)(AVAssetTrack *))transformToApply withErrorHandler:(void (^)(NSError *))errorHandler
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:clip.URL options:nil];
    
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    
    if (videoTracks.count == 0) return;
    
    AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
    
    //
    // Apply a transformation to the video if one has been given. If a transformation is given it is combined
    // with the preferred transform contained in the incoming video track.
    //
    
    //[layerInstruction setTransform:videoTrack.preferredTransform atTime:kCMTimeZero];
    
//    if(transformToApply)
//    {
//        [layerInstruction setTransform:CGAffineTransformConcat(videoTrack.preferredTransform, transformToApply(videoTrack))
//                                atTime:kCMTimeZero];
//    }
//    else
//    {
//        [layerInstruction setTransform:videoTrack.preferredTransform
//                                atTime:kCMTimeZero];
//    }
    
    [layerInstruction setTransform:videoTrack.preferredTransform atTime:kCMTimeZero];
    
    instruction.layerInstructions = @[layerInstruction];
    
    __block CMTime startTime = kCMTimeZero;
    [instructions enumerateObjectsUsingBlock:^(AVMutableVideoCompositionInstruction *previousInstruction, NSUInteger idx, BOOL *stop) {
        startTime = CMTimeAdd(startTime, previousInstruction.timeRange.duration);
    }];
    
    CMTimeRange range = CMTimeRangeMake(startTime, asset.duration);
    instruction.timeRange = range;
    
    [instructions addObject:instruction];
    
    NSError *error;
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoTrack atTime:kCMTimeZero error:&error];
    
    if(error){
        errorHandler(error);
        return;
    }
    
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    if (audioTracks.count == 0) return;
    
    AVAssetTrack *audioTrack = [audioTracks objectAtIndex:0];
    
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:&error];
    
    if(error){
        errorHandler(error);
        return;
    }
}

- (void)exportTo:(NSURL *)outputFile withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))completionHandler
{
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    
    videoComposition.instructions = instructions;
    videoComposition.renderSize = outputSize;
    
    AVMutableVideoCompositionInstruction *lastInstruction = ((AVMutableVideoCompositionInstruction *)instructions.lastObject);
    videoComposition.frameDuration = CMTimeAdd(lastInstruction.timeRange.start, lastInstruction.timeRange.duration);
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:self.composition presetName:preset];
    NSParameterAssert(exporter != nil);
    
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.videoComposition = videoComposition;
    exporter.outputURL = outputFile;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        switch([exporter status])
        {
            case AVAssetExportSessionStatusFailed:
            {
                completionHandler(exporter.error);
            } break;
            case AVAssetExportSessionStatusCancelled:
            case AVAssetExportSessionStatusCompleted:
            {
                completionHandler(nil);
            } break;
            default:
            {
                completionHandler([NSError errorWithDomain:@"Unknown export error" code:100 userInfo:nil]);
            } break;
        }
        
    }];
}

@end

