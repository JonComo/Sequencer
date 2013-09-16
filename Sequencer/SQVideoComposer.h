//
//  SQVideoComposer.h
//  Sequencer
//
//  Created by Jon Como on 9/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

@interface SQVideoComposer : NSObject

- (void)exportClips:(NSArray *)clips toURL:(NSURL *)outputFile withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))block;
- (NSArray *)compositionFromClips:(NSArray *)clips;

@end