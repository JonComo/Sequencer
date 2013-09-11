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

+ (void)stretchClip:(SRClip *)clip byAmount:(float)multiple completion:(StretchCompletion)block
{
    AVURLAsset *asset = [AVURLAsset assetWithURL:clip.URL];
    
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *mutableCompositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//    AVMutableCompositionTrack *mutableCompositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //Add video
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    [mutableCompositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoAssetTrack.timeRange.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    
    //Add audio
//    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
//    
//    [mutableCompositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    
    double wholeDuration = CMTimeGetSeconds([asset duration]);
    double doubleDuration = CMTimeGetSeconds([asset duration]) * multiple;
    
    [mutableComposition scaleTimeRange:mutableCompositionVideoTrack.timeRange toDuration:CMTimeMakeWithSeconds(doubleDuration, 600.0)];
    
    //Audio
    
    
    //NSURL *audioURL = [[[SRClip uniqueFileURLInDirectory:DOCUMENTS] URLByDeletingPathExtension] URLByAppendingPathExtension:@"m4a"];
//    
//    AVAssetReader *audioReader = [AVAssetReader assetReaderWithAsset:asset error:nil];
//    
//    AVAssetReaderTrackOutput *audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack outputSettings:nil];
//    
//    [audioReader addOutput:audioOutput];
//    
//    CMItemCount countsample;
//    CMSampleBufferRef nextBuffer;
//    NSMutableData *samples = [NSMutableData data];
//    
//    [audioReader startReading];
//    
//    while(countsample)
//    {
//        nextBuffer = [audioOutput copyNextSampleBuffer];
//        if(nextBuffer)
//        {
//            countsample = CMSampleBufferGetNumSamples(nextBuffer);
//            [samples appendBytes:nextBuffer length:countsample];
//        }else{
//            [audioReader cancelReading];
//        }
//    }
    
    
    
    NSURL *exportURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:mutableComposition presetName:AVAssetExportPreset640x480];
    
    NSParameterAssert(exporter != nil);
    
    exporter.outputFileType = AVFileTypeMPEG4;
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
                
            } break;
            default:
            {
                if (block) block(nil);
            } break;
        }
        
    }];
}

/*
- (void)modifySpeedOf:(CFURLRef)inputURL byFactor:(float)factor andWriteTo:(CFURLRef)outputURL {
    
    ExtAudioFileRef inputFile = NULL;
    ExtAudioFileRef outputFile = NULL;
    
    AudioStreamBasicDescription destFormat;
    
    destFormat.mFormatID = kAudioFormatLinearPCM;
    destFormat.mFormatFlags = kAudioFormatFlagsCanonical;
    destFormat.mSampleRate = 44100 * factor;
    destFormat.mBytesPerPacket = 2;
    destFormat.mFramesPerPacket = 1;
    destFormat.mBytesPerFrame = 2;
    destFormat.mChannelsPerFrame = 1;
    destFormat.mBitsPerChannel = 16;
    destFormat.mReserved = 0;
    
    ExtAudioFileCreateWithURL(outputURL, kAudioFileCAFType,
                              &destFormat, NULL, kAudioFileFlags_EraseFile, &outputFile);
    
    ExtAudioFileOpenURL(inputURL, &inputFile);
    
    //find out how many frames is this file long
    SInt64 length = 0;
    UInt32 dataSize2 = (UInt32)sizeof(length);
    ExtAudioFileGetProperty(inputFile,
                            kExtAudioFileProperty_FileLengthFrames, &dataSize2, &length);
    
    SInt16 *buffer = (SInt16*)malloc(kBufferSize * sizeof(SInt16));
    
    UInt32 totalFramecount = 0;
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = 1;
    bufferList.mBuffers[0].mData = buffer; // pointer to buffer of audio data
    bufferList.mBuffers[0].mDataByteSize = kBufferSize *
    sizeof(SInt16); // number of bytes in the buffer
    
    while(true) {
        
        UInt32 frameCount = kBufferSize * sizeof(SInt16) / 2;
        // Read a chunk of input
        ExtAudioFileRead(inputFile, &frameCount, &bufferList);
        totalFramecount += frameCount;
        
        if (!frameCount || totalFramecount >= length) {
            //termination condition
            break;
        }
        ExtAudioFileWrite(outputFile, frameCount, &bufferList);
    }
    
    free(buffer);
    
    ExtAudioFileDispose(inputFile);
    ExtAudioFileDispose(outputFile);
    
}
*/
@end
