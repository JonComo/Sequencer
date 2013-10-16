//
//  SQEffect.m
//  Sequencer
//
//  Created by Jon Como on 10/15/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQEffect.h"

@implementation SQEffect

-(id)initWithClip:(SRClip *)aClip
{
    if (self = [super init]) {
        //init
        _clip = aClip;
    }
    
    return self;
}

-(void)renderEffectCompletion:(void (^)(SRClip *))block
{
    if (block) block(nil);
}

@end