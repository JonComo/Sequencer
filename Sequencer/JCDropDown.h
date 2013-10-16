//
//  JCDropDown.h
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^ActionBlock)(void);

@interface JCDropDown : UIButton

//as menu item
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) ActionBlock action;

//as menu header
@property (nonatomic, strong) NSMutableArray *actions;

//as menu item
+(JCDropDown *)dropDownActionWithName:(NSString *)actionName action:(ActionBlock)actionBlock;
-(void)rolledOver;
-(void)rolledOut;
-(void)touchedUpInside;

//as menu header
-(BOOL)isShowingSubmenu;
-(CGSize)sizeForMenuItems;
-(CGRect)submenuFrame;

@end