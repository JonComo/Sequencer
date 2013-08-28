//
//  SRClip.h
//  SequenceRecord
//
//  Created by Jon Como on 8/5/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SRClip : NSObject

@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, strong) NSURL *URL;

-(id)initWithURL:(NSURL *)URL;

-(void)generateThumbnailCompletion:(void(^)(BOOL success))block;

+(NSURL *)uniqueFileURLInDirectory:(NSString *)directory;

-(SRClip *)duplicate;

@end