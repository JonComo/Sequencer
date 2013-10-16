//
//  SQEffect.h
//  Sequencer
//
//  Created by Jon Como on 10/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SRClip.h"

@interface SQEffect : NSObject

@property (nonatomic, strong) SRClip *clip;

-(id)initWithClip:(SRClip *)aClip;

-(void)renderEffectCompletion:(void(^)(SRClip *output))block;

@end