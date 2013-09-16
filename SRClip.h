//
//  SRClip.h
//  SequenceRecord
//
//  Created by Jon Como on 8/5/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "Macros.h"

@interface SRClip : NSObject

@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, strong) NSMutableArray *thumbnails;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) AVURLAsset *asset;

@property BOOL isSelected;

-(id)initWithURL:(NSURL *)URL;

-(void)generateThumbnailsCompletion:(void(^)(NSError *error))block;

+(NSURL *)uniqueFileURLInDirectory:(NSString *)directory;

//Clip operations

-(SRClip *)duplicate;
-(BOOL)remove;
-(NSError *)replaceWithFileAtURL:(NSURL *)newURL;

-(CGSize)timelineSize;

@end