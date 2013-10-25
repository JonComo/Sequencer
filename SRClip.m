//
//  SRClip.m
//  SequenceRecord
//
//  Created by Jon Como on 8/5/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SRClip.h"
#import "Macros.h"

@implementation SRClip

-(id)initWithURL:(NSURL *)URL
{
    if (self = [super init]) {
        //init
        _URL = URL;
    }
    
    return self;
}

-(void)refreshProperties
{
    self.asset = [[AVURLAsset alloc] initWithURL:_URL options:nil];
    self.timelineSize = [self calculateTimelineSize];
}

-(AVAssetTrack *)trackWithMediaType:(NSString *)type
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.URL options:nil];
    
    NSArray *tracks = [asset tracksWithMediaType:type];
    
    AVAssetTrack *track;
    
    if (tracks.count > 0)
        track = tracks[0];
    
    return track;
}

-(void)dealloc
{
    
}

+(NSURL *)uniqueFileURLInDirectory:(NSString *)directory
{
    NSURL *returnURL;
    
    int i = 0;
    
    do {
        returnURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/clip%i.mov", directory, i]];
        i++;
    } while ([[NSFileManager defaultManager] fileExistsAtPath:[returnURL path]]);
    
    return returnURL;
}

-(SRClip *)duplicate
{
    NSURL *newURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    NSError *error;
    [[NSFileManager defaultManager] copyItemAtURL:self.URL toURL:newURL error:&error];
    
    SRClip *newClip;
    
    if (!error)
        newClip = [[SRClip alloc] initWithURL:newURL];
    
    newClip.thumbnails = self.thumbnails;
    [newClip refreshProperties];
    
    return newClip;
}

-(BOOL)remove
{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:self.URL error:&error];
    
    return error ? NO : YES;
}

-(NSError *)replaceWithFileAtURL:(NSURL *)newURL
{
    NSError *error;
    
    [[NSFileManager defaultManager] replaceItemAtURL:self.URL withItemAtURL:newURL backupItemName:@"backup" options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:&newURL error:&error];
    
    if (!error)
        [self refreshProperties];
    
    return error;
}

-(CGSize)calculateTimelineSize
{
    CGSize defaultSize = CGSizeMake(60, 60);
    
    return CGSizeMake(CMTimeGetSeconds(self.asset.duration) * 45, defaultSize.height);
}

-(void)generateThumbnailsCompletion:(void (^)(NSError *))block
{
    [self refreshProperties];
    [self generateThumbnailsForSize:self.timelineSize completion:^(NSError *error, NSArray *thumbnails) {
        self.thumbnails = thumbnails;
        if (block) block(error);
    }];
}

-(void)generateThumbnailsForSize:(CGSize)size completion:(void(^)(NSError *error, NSArray *thumbnails))block;
{
    NSMutableArray *thumbnails = [NSMutableArray array];
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.URL options:nil];
    
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    
    //imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    //imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    
    int picWidth = size.height;
    imageGenerator.maximumSize = CGSizeMake(picWidth, picWidth);
    
    //Generate rest of the images
    CMTime duration = asset.duration;
    
    int numberToGenerate = ceil(size.width / picWidth);
    numberToGenerate -= 2; //account for the start and end thumb
    
    NSMutableArray *times = [NSMutableArray array];
    
    [times addObject:[NSValue valueWithCMTime:kCMTimeZero]]; //first image
    
    float offsetX = 0;
    
    for (int i = 0; i<numberToGenerate; i++)
    {
        offsetX += picWidth;
        
        //float ratio = offsetX / size.width;
        
        //CMTime timeFrame = CMTimeMultiplyByFloat64(duration, ratio);
        CMTime timeFrame = CMTimeMake(offsetX, 30);
        
        NSLog(@"Generating thumbnails for time: %lld timescale: %d", timeFrame.value, timeFrame.timescale);
        
        [times addObject:[NSValue valueWithCMTime:timeFrame]];
    }
    
    [times addObject:[NSValue valueWithCMTime:asset.duration]]; //last image
    
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error)
     {
         if (result == AVAssetImageGeneratorSucceeded) {
             
             UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 [thumbnails addObject:thumb];
                 
                 if (thumbnails.count == times.count)
                     if (block) block(nil, thumbnails);
             });
         }
         
         if (result == AVAssetImageGeneratorFailed) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (block) block(error, nil);
             });
         }
         if (result == AVAssetImageGeneratorCancelled) {
             if (block) block([NSError errorWithDomain:@"Canceled" code:0 userInfo:nil], nil);
         }
     }];
}

-(BOOL)isPlayingAtTime:(CMTime)time
{
    BOOL withinTime = CMTimeRangeContainsTime(self.positionInComposition, time);
    
    if (withinTime) return withinTime;
    
    //check if ends equal
    if (CMTimeCompare(time, CMTimeAdd(self.positionInComposition.start, self.positionInComposition.duration)) == 0) return YES;
    
    return NO;
}

-(void)modifyLayerInstruction:(AVMutableVideoCompositionLayerInstruction *)layerInstruction inRange:(CMTimeRange)range
{
    [layerInstruction setOpacityRampFromStartOpacity:0 toEndOpacity:1 timeRange:range];
}

@end