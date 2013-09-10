//
//  SQClipTimeStretch.h
//  Sequencer
//
//  Created by Jon Como on 9/10/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

@class  SRClip;

typedef void (^StretchCompletion)(SRClip *stretchedClip);

@interface SQClipTimeStretch : NSObject

- (void)stretchClip:(SRClip *)clip byPercent:(float)percent completion:(StretchCompletion)block;

@end
