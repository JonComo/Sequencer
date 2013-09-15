//
//  JCMath.h
//  MyNeuralNetwork
//
//  Created by Jon Como on 11/26/12.
//  Copyright (c) 2012 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCMath : NSObject

#pragma Math functions

+(float)angleFromPoint:(CGPoint)point1 toPoint:(CGPoint)point2;
+(double)distanceBetweenPoint:(CGPoint)point1 andPoint:(CGPoint)point2 sorting:(BOOL)sorting;
+(CGPoint)pointFromPoint:(CGPoint)point pushedBy:(float)pushAmount inDirection:(float)degrees;
+(float)mapValue:(float)value range:(CGPoint)range1 range:(CGPoint)range2;

@end
