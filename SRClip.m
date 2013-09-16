//
//  SRClip.m
//  SequenceRecord
//
//  Created by Jon Como on 8/5/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SRClip.h"
#import "Macros.h"
#import <AVFoundation/AVFoundation.h>

@implementation SRClip

-(id)initWithURL:(NSURL *)URL
{
    if (self = [super init]) {
        //init
        _URL = URL;
        _asset = [AVURLAsset URLAssetWithURL:URL options:nil];
    }
    
    return self;
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
    return CGSizeMake(80 + CMTimeGetSeconds(self.asset.duration) * 40, 80);
}

-(void)generateThumbnailsCompletion:(void(^)(NSError *error))block
{
    if (!self.thumbnails)
        self.thumbnails = [NSMutableArray array];
    
    [self.thumbnails removeAllObjects];
    
    CGSize size = [self timelineSize];
    
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    
    int picWidth = size.height;
    imageGenerator.maximumSize = CGSizeMake(picWidth, picWidth);
    
    //Generate rest of the images
    float durationSeconds = CMTimeGetSeconds([self.asset duration]);
    
    int numberOfPics = size.width / picWidth;
    
    NSMutableArray *times = [NSMutableArray array];
    
    for (int i = 0; i<numberOfPics; i++)
    {
        int timeForThumb = i * picWidth;
        CMTime timeFrame = CMTimeMakeWithSeconds(durationSeconds * timeForThumb / size.width, 600);
        
        [times addObject:[NSValue valueWithCMTime:timeFrame]];
    }
    
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error)
     {
         if (result == AVAssetImageGeneratorSucceeded) {
             
             UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 [self.thumbnails addObject:thumb];
                 
                 if (self.thumbnails.count == numberOfPics)
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

@end