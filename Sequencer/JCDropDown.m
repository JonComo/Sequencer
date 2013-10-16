//
//  JCDropDown.m
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCDropDown.h"

@implementation JCDropDown
{
    UIView *dropDownView;
    UIView *viewIndicateMore;
    
    CGSize sizeForMenu;

    UILabel *labelName;
}

#pragma Menu item:

+(UIFont *)defaultFont
{
    return [UIFont boldSystemFontOfSize:16];
}

+(JCDropDown *)dropDownActionWithName:(NSString *)actionName action:(ActionBlock)actionBlock
{
    CGSize size = [actionName sizeWithAttributes:@{NSFontAttributeName : [JCDropDown defaultFont]}];
    
    if (size.width < 130)
        size.width = 130;
    if (size.height < 30)
        size.height = 30;
    
    JCDropDown *action = [[self alloc] initWithFrame:CGRectMake(0, 0, size.width + 20, size.height)];
    
    action.name = actionName;
    action.action = actionBlock;
    
    return action;
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        self.backgroundColor = [UIColor whiteColor];
        
        labelName = [[UILabel alloc] initWithFrame:frame];
        labelName.backgroundColor = [UIColor clearColor];
        labelName.textColor = [UIColor blackColor];
        labelName.font = [JCDropDown defaultFont];
        labelName.textAlignment = NSTextAlignmentCenter;
        
        [self addSubview:labelName];
    }
    
    return self;
}

-(void)setName:(NSString *)name
{
    _name = name;
    labelName.text = name;
}

-(void)setActions:(NSMutableArray *)actions
{
    _actions = actions;
    
    sizeForMenu = [self sizeForMenuItems];
    
    /*
    if (actions.count > 0){
        viewIndicateMore = [[UIView alloc] initWithFrame:CGRectMake(self.frame.size.width - 10, 5, 10, self.frame.size.height - 10)];
        viewIndicateMore.backgroundColor = [UIColor blackColor];
        [self addSubview:viewIndicateMore];
    } */
}

-(void)rolledOver
{
    self.backgroundColor = [UIColor blackColor];
    
    labelName.textColor = [UIColor whiteColor];
    viewIndicateMore.backgroundColor = [UIColor whiteColor];
    
    [self showDropDown];
}

-(void)rolledOut
{
    self.backgroundColor = [UIColor whiteColor];
    
    labelName.textColor = [UIColor blackColor];
    viewIndicateMore.backgroundColor = [UIColor blackColor];
    
    [dropDownView removeFromSuperview];
}

-(void)touchedUpInside
{
    if(self.action) self.action();
}

#pragma Menu header:

-(void)showDropDown
{
    if (!dropDownView)
    {
        dropDownView = [[UIView alloc] initWithFrame:CGRectMake(self.frame.size.width, self.frame.size.height/2 - sizeForMenu.height/2, sizeForMenu.width, sizeForMenu.height)];
        
        dropDownView.backgroundColor = [UIColor clearColor];
        
        [dropDownView setUserInteractionEnabled:YES];
        
        float offsetY = 0;
        
        for (JCDropDown *action in self.actions)
        {
            action.frame = CGRectOffset(action.frame, 0, offsetY);
            offsetY += action.frame.size.height;
            
            [dropDownView addSubview:action];
        }
    }
    
    [self addSubview:dropDownView];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (dropDownView.superview)
    {
        [dropDownView removeFromSuperview];
    }else
    {
        [self showDropDown];
    }
    
    [self pushTouchesToActions:touches withEvent:event ended:NO];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self pushTouchesToActions:touches withEvent:event ended:NO];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self pushTouchesToActions:touches withEvent:event ended:YES];
    
    [dropDownView removeFromSuperview];
}

-(void)pushTouchesToActions:(NSSet *)touches withEvent:(UIEvent *)event ended:(BOOL)ended
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:dropDownView];
    
    for (JCDropDown *submenu in self.actions)
    {
        BOOL touchInSubmenuHeader = CGRectContainsPoint(submenu.frame, location);
        CGPoint relativeLocation = [touch locationInView:submenu];
        
        if (touchInSubmenuHeader || (submenu.isShowingSubmenu && CGRectContainsPoint([submenu submenuFrame], relativeLocation)))
        {
            if (ended){
                [submenu touchedUpInside];
            }
            
            [submenu rolledOver];
            
            if (submenu.actions.count != 0)
            {
                [submenu pushTouchesToActions:touches withEvent:event ended:ended];
            }
            
        }else{
            [submenu rolledOut];
        }
    }
}

-(CGSize)sizeForMenuItems
{
    if (self.actions.count == 0)
    {
        return self.frame.size;
    }
    
    float width = 0;
    float height = 0;
    
    for (JCDropDown *action in self.actions){
        if (action.frame.size.width > width)
            width = action.frame.size.width;
        
        height += action.frame.size.height;
    }
    
    return CGSizeMake(width, height);
}

-(CGRect)submenuFrame
{
    CGRect frame = CGRectMake(self.frame.size.width, self.frame.size.height/2 - sizeForMenu.height/2, sizeForMenu.width, sizeForMenu.height);
    
    //NSLog(@"SUBFRAME %f %f size %f %f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
    
    return frame;
}

-(BOOL)isShowingSubmenu
{
    return dropDownView.superview ? YES : NO;
}

@end