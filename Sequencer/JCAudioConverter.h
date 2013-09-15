//
//  JCAudioConverter.h
//  Sequencer
//
//  Created by Jon Como on 9/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCAudioConverter : NSObject

+(void)convertAudioAtURL:(NSURL *)audioURL compress:(BOOL)compress completion:(void(^)(NSURL *convertedURL))block;

@end