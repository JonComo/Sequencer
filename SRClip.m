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
    }
    
    return self;
}

-(void)generateThumbnailCompletion:(void (^)(BOOL success))block
{
    [self thumbnailCompletion:^(UIImage *thumb) {
        _thumbnail = thumb;
        if (block) block(YES);
    }];
}

-(void)thumbnailCompletion:(void (^)(UIImage *thumb))block
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.URL options:nil];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    //generator.appliesPreferredTrackTransform = YES;
    
    CMTime thumbTime = CMTimeMakeWithSeconds(0,30);
    
    CGSize maxSize = CGSizeMake(100, 100);
    generator.maximumSize = maxSize;
    [generator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:thumbTime]] completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        if (result != AVAssetImageGeneratorSucceeded) {
            NSLog(@"couldn't generate thumbnail, error:%@", error);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block) block(nil);
            });
            
            return;
        }
        
        UIImage *thumb = [UIImage imageWithCGImage:image];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) block(thumb);
        });
    }];
}

+(NSURL *)uniqueFileURLInDirectory:(NSString *)directory
{
    NSURL *returnURL;
    
    do {
        returnURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/clip%f.mov", directory, [[NSDate date] timeIntervalSince1970]]];
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

@end