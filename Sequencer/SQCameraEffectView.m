//
//  SQCameraEffectView.m
//  Sequencer
//
//  Created by Jon Como on 9/30/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQCameraEffectView.h"

#import "PerlinNoise.h"

@implementation SQCameraEffectView
{
    PerlinNoise *noise;
    NSTimer *timer;
    
    float noiseOffset;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        //init
        noise = [[PerlinNoise alloc] initWithSeed:arc4random()];
        noise.frequency = 0.15;
        noise.octaves = 2;
        noiseOffset = 0;
    }
    
    return self;
}

-(void)startAnimating
{
    [timer invalidate];
    timer = nil;
    
    timer = [NSTimer scheduledTimerWithTimeInterval:1/14 target:self selector:@selector(setNeedsDisplay) userInfo:nil repeats:YES];
}

-(void)stopAnimating
{
    [timer invalidate];
    timer = nil;
}

-(float)rand
{
    return (float)(arc4random()%100) / 100.0f;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    noiseOffset += 0.01;
    
    //// Color Declarations
    UIColor* fillColor = [UIColor whiteColor];
    UIColor* strokeColor = [UIColor blackColor];
    
    //// Frames
    CGRect frame = rect;
    
    //// Subframes
    CGRect group2 = CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame), CGRectGetWidth(frame), CGRectGetHeight(frame));
    
    
    //// Group 2
    {
        //// Rectangle Drawing
        UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.00000 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.00000 + 0.5), floor(CGRectGetWidth(group2) * 1.00000 + 0.5) - floor(CGRectGetWidth(group2) * 0.00000 + 0.5), floor(CGRectGetHeight(group2) * 1.00000 + 0.5) - floor(CGRectGetHeight(group2) * 0.00000 + 0.5))];
        [strokeColor setFill];
        [rectanglePath fill];
        [strokeColor setStroke];
        rectanglePath.lineWidth = 1;
        [rectanglePath stroke];
        
        
        fillColor = [self colorFromNoiseOffset:0];
        strokeColor = [UIColor colorWithRed:[self rand] green:[self rand] blue:[self rand] alpha:1];
        
        //// Rectangle 2 Drawing
        UIBezierPath* rectangle2Path = [UIBezierPath bezierPathWithRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.08333 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.27000 + 0.5), floor(CGRectGetWidth(group2) * 0.93000 + 0.5) - floor(CGRectGetWidth(group2) * 0.08333 + 0.5), floor(CGRectGetHeight(group2) * 0.73333 + 0.5) - floor(CGRectGetHeight(group2) * 0.27000 + 0.5))];
        [fillColor setFill];
        [rectangle2Path fill];
        
        fillColor = [UIColor whiteColor];
        strokeColor = [UIColor blackColor];
        
        
        //// Bezier 2 Drawing
        UIBezierPath* bezier2Path = [UIBezierPath bezierPath];
        [bezier2Path moveToPoint: CGPointMake(CGRectGetMinX(group2) + 0.69833 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.41167 * CGRectGetHeight(group2))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.87500 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.74333 * CGRectGetHeight(group2))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.94333 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.74333 * CGRectGetHeight(group2))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.94333 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.44667 * CGRectGetHeight(group2))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.85167 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.30500 * CGRectGetHeight(group2))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.69833 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.30500 * CGRectGetHeight(group2))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.69833 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.41167 * CGRectGetHeight(group2))];
        [bezier2Path closePath];
        [strokeColor setFill];
        [bezier2Path fill];
        
        
        fillColor = [self colorFromNoiseOffset:1];
        strokeColor = [UIColor colorWithRed:[self rand] green:[self rand] blue:[self rand] alpha:1];
        
        //// Rectangle 3 Drawing
        UIBezierPath* rectangle3Path = [UIBezierPath bezierPathWithRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.69333 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.30333 + 0.5), floor(CGRectGetWidth(group2) * 0.85333 + 0.5) - floor(CGRectGetWidth(group2) * 0.69333 + 0.5), floor(CGRectGetHeight(group2) * 0.41000 + 0.5) - floor(CGRectGetHeight(group2) * 0.30333 + 0.5))];
        [fillColor setFill];
        [rectangle3Path fill];
        
        fillColor = [UIColor whiteColor];
        strokeColor = [UIColor blackColor];
        
        
        //// Rectangle 4 Drawing
        UIBezierPath* rectangle4Path = [UIBezierPath bezierPathWithRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.72000 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.32667 + 0.5), floor(CGRectGetWidth(group2) * 0.83000 + 0.5) - floor(CGRectGetWidth(group2) * 0.72000 + 0.5), floor(CGRectGetHeight(group2) * 0.38667 + 0.5) - floor(CGRectGetHeight(group2) * 0.32667 + 0.5))];
        [strokeColor setFill];
        [rectangle4Path fill];
        
        
        //// Group
        {
            //// Bezier Drawing
            UIBezierPath* bezierPath = [UIBezierPath bezierPath];
            [bezierPath moveToPoint: CGPointMake(CGRectGetMinX(group2) + 0.30333 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.57833 * CGRectGetHeight(group2))];
            [bezierPath addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.36000 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.74000 * CGRectGetHeight(group2))];
            [bezierPath addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.81667 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.74000 * CGRectGetHeight(group2))];
            [bezierPath addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.66167 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.41833 * CGRectGetHeight(group2))];
            [bezierPath addLineToPoint: CGPointMake(CGRectGetMinX(group2) + 0.30333 * CGRectGetWidth(group2), CGRectGetMinY(group2) + 0.57833 * CGRectGetHeight(group2))];
            [bezierPath closePath];
            [strokeColor setFill];
            [bezierPath fill];
            
            
            //// Oval Drawing
            UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.29000 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.31000 + 0.5), floor(CGRectGetWidth(group2) * 0.68333 + 0.5) - floor(CGRectGetWidth(group2) * 0.29000 + 0.5), floor(CGRectGetHeight(group2) * 0.70667 + 0.5) - floor(CGRectGetHeight(group2) * 0.31000 + 0.5))];
            [strokeColor setFill];
            [ovalPath fill];
        }
        
        fillColor = [self colorFromNoiseOffset:1.8];
        strokeColor = [UIColor colorWithRed:[self rand] green:[self rand] blue:[self rand] alpha:1];
        
        //// Oval 2 Drawing
        UIBezierPath* oval2Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.31667 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.33667 + 0.5), floor(CGRectGetWidth(group2) * 0.65667 + 0.5) - floor(CGRectGetWidth(group2) * 0.31667 + 0.5), floor(CGRectGetHeight(group2) * 0.67667 + 0.5) - floor(CGRectGetHeight(group2) * 0.33667 + 0.5))];
        [fillColor setFill];
        [oval2Path fill];
        
        
        fillColor = [UIColor whiteColor];
        strokeColor = [UIColor blackColor];
        
        //// Oval 3 Drawing
        UIBezierPath* oval3Path = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(group2) + floor(CGRectGetWidth(group2) * 0.36000 + 0.5), CGRectGetMinY(group2) + floor(CGRectGetHeight(group2) * 0.37667 + 0.5), floor(CGRectGetWidth(group2) * 0.61333 + 0.5) - floor(CGRectGetWidth(group2) * 0.36000 + 0.5), floor(CGRectGetHeight(group2) * 0.63000 + 0.5) - floor(CGRectGetHeight(group2) * 0.37667 + 0.5))];
        [strokeColor setFill];
        [oval3Path fill];
    }
}

-(UIColor *)colorFromNoiseOffset:(float)offset
{
    float p1 = noiseOffset + offset;
    float n1 = [noise perlin1DValueForPoint:p1] + 0.5;
    
    return [UIColor colorWithHue:n1 saturation:1 brightness:1 alpha:1];
}

@end
