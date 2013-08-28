//
//  SRClip.h
//  SequenceRecord
//
//  Created by Jon Como on 8/5/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SRClipNotificationDidGenerateThumbnail @"clipGeneratedThumbnail"
#define SRClipNotificationFailed @"clipFailed"

@interface SRClip : NSObject

@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, strong) NSURL *URL;

-(id)initWithURL:(NSURL *)URL;

-(void)generateThumbnail;

+(NSURL *)uniqueFileURLInDirectory:(NSString *)directory;

-(SRClip *)duplicate;

@end