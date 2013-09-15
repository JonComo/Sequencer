//
//  JCDropDownAction.h
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^ActionBlock)(void);

@interface JCDropDownAction : UIView

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) ActionBlock action;

+(JCDropDownAction *)dropDownActionWithName:(NSString *)actionName action:(ActionBlock)actionBlock;

-(void)rolledOver;
-(void)rolledOut;
-(void)touchedUpInside;

@end
