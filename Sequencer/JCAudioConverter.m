//
//  JCAudioConverter.m
//  Sequencer
//
//  Created by Jon Como on 9/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCAudioConverter.h"

#import <AVFoundation/AVFoundation.h>

@implementation JCAudioConverter

+(void)convertAudioAtURL:(NSURL *)audioURL compress:(BOOL)compress completion:(void(^)(NSURL *convertedURL))block
{
    // reader
    AVAsset *asset = [AVAsset assetWithURL:audioURL];
    
    NSError *readerError;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&readerError];
    
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    AVAssetReaderTrackOutput *readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:compress ? nil : [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                                    @(kAudioFormatLinearPCM), AVFormatIDKey,
                                                                                                                                     @(44100.0), AVSampleRateKey,
                                                                                                                                     @(2), AVNumberOfChannelsKey,
                                                                                                                                     @(16), AVLinearPCMBitDepthKey,
                                                                                                                                     @(NO), AVLinearPCMIsBigEndianKey,
                                                                                                                                     @(NO), AVLinearPCMIsFloatKey,
                                                                                                                                     @(NO), AVLinearPCMIsNonInterleaved,
                                                                                                                                     [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                                                                                                                     nil]];
    [reader addOutput:readerOutput];
    
    NSURL *outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent: compress ? @"audio.m4a" : @"audio.aif"]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[outputURL path]]){
        [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
    }
    
    // writer
    NSError *writerError;
    NSString *fileType = compress ? AVFileTypeAppleM4A : AVFileTypeWAVE;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outputURL
                                                      fileType:fileType
                                                         error:&writerError];
    
    
    
    // use different values to affect the downsampling/compression
    NSDictionary *outputSettings = compress ? [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                               [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                               [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                               [NSNumber numberWithInt:128000], AVEncoderBitRateKey,
                                               [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                               nil] :
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInt: kAudioFormatLinearPCM], AVFormatIDKey,
     [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
     [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
     [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
     [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
     [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
     [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
     [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
     nil];
    
    AVAssetWriterInput *writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                                     outputSettings:outputSettings];
    [writerInput setExpectsMediaDataInRealTime:NO];
    [writer addInput:writerInput];
    
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    [reader startReading];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    [writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        NSLog(@"Asset Writer ready : %d", writerInput.readyForMoreMediaData);
        while (writerInput.readyForMoreMediaData) {
            CMSampleBufferRef nextBuffer;
            if ([reader status] == AVAssetReaderStatusReading && (nextBuffer = [readerOutput copyNextSampleBuffer])) {
                if (nextBuffer) {
                    NSLog(@"Adding buffer");
                    [writerInput appendSampleBuffer:nextBuffer];
                }
            } else {
                [writerInput markAsFinished];
                
                switch ([reader status]) {
                    case AVAssetReaderStatusReading:
                        break;
                    case AVAssetReaderStatusFailed:
                    {
                        [writer cancelWriting];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (block) block(nil);
                        });
                    }
                        break;
                    case AVAssetReaderStatusCompleted:
                        NSLog(@"Writer completed");
                        [writer endSessionAtSourceTime:asset.duration];
                        [writer finishWriting];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (block) block(outputURL);
                        });
                        break;
                }
                break;
            }
        }
    }];
}

@end