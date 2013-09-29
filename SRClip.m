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
        //_asset = [AVURLAsset URLAssetWithURL:URL options:nil];
    }
    
    return self;
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
    
    newClip.thumbnails = [self.thumbnails mutableCopy];
    
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
        
    return error;
}

-(CGSize)timelineSize
{
    CGSize defaultSize = CGSizeMake(60, 60);
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.URL options:nil];
    
    return CGSizeMake(defaultSize.width + CMTimeGetSeconds(asset.duration) * (defaultSize.width/2), defaultSize.height);
}

-(void)generateThumbnailsCompletion:(void (^)(NSError *))block
{
    [self generateThumbnailsForSize:[self timelineSize] completion:block];
}

-(void)generateThumbnailsForSize:(CGSize)size completion:(void(^)(NSError *error))block
{
    if (!self.thumbnails)
        self.thumbnails = [NSMutableArray array];
    
    [self.thumbnails removeAllObjects];
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.URL options:nil];
    
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    
    int picWidth = size.height;
    imageGenerator.maximumSize = CGSizeMake(picWidth, picWidth);
    
    //Generate rest of the images
    float durationSeconds = CMTimeGetSeconds(asset.duration);
    
    int numberToGenerate = ceil(size.width / picWidth);
    numberToGenerate -= 2; //account for the start and end thumb
    
    NSMutableArray *times = [NSMutableArray array];
    
    [times addObject:[NSValue valueWithCMTime:kCMTimeZero]]; //first image
    
    for (int i = 0; i<numberToGenerate; i++)
    {
        int timeForThumb = i * picWidth;
        CMTime timeFrame = CMTimeMakeWithSeconds(durationSeconds * timeForThumb / size.width, 600);
        
        [times addObject:[NSValue valueWithCMTime:timeFrame]];
    }
    
    [times addObject:[NSValue valueWithCMTime:asset.duration]]; //last image
    
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error)
     {
         if (result == AVAssetImageGeneratorSucceeded) {
             
             UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 [self.thumbnails addObject:thumb];
                 
                 if (self.thumbnails.count == times.count)
                     if (block) block(nil);
                 
             });
         }
         
         if (result == AVAssetImageGeneratorFailed) {
             if (block) block(error);
         }
         if (result == AVAssetImageGeneratorCancelled) {
             if (block) block([NSError errorWithDomain:@"Canceled" code:0 userInfo:nil]);
         }
     }];
}

-(BOOL)isPlayingAtTime:(CMTime)time
{
    if (CMTimeCompare(time, self.positionInComposition.start) == 1 && CMTimeCompare(time, CMTimeAdd(self.positionInComposition.start, self.positionInComposition.duration)) == -1)
    {
        return YES;
    }
    
    return NO;
}

-(void)modifyLayerInstruction:(AVMutableVideoCompositionLayerInstruction *)layerInstruction inRange:(CMTimeRange)range
{
    [layerInstruction setOpacityRampFromStartOpacity:0 toEndOpacity:1 timeRange:range];
}

@end