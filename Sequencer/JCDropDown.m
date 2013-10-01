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
    CGSize sizeForMenu;
}

-(void)showDropDown
{
    if (!dropDownView)
    {
        sizeForMenu = [self sizeForMenuItems];
        float offsetY = 0;
        
        dropDownView = [[UIView alloc] initWithFrame:CGRectMake(self.frame.size.width + 20, self.frame.size.height/2 - sizeForMenu.height/2, sizeForMenu.width, sizeForMenu.height)];
        
        dropDownView.backgroundColor = [UIColor clearColor];
        
        [dropDownView setUserInteractionEnabled:YES];
        
        for (JCDropDownAction *action in self.actions)
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
    if (self.actions.count == 0){
        [super touchesBegan:touches withEvent:event];
        return;
    }
    
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
    if (self.actions.count == 0){
        [super touchesEnded:touches withEvent:event];
        return;
    }
    
    [self pushTouchesToActions:touches withEvent:event ended:YES];
    
    [dropDownView removeFromSuperview];
}

-(void)pushTouchesToActions:(NSSet *)touches withEvent:(UIEvent *)event ended:(BOOL)ended
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:dropDownView];
    
    for (JCDropDownAction *action in self.actions)
    {
        if (CGRectContainsPoint(action.frame, location)){
            if (ended)
            {
                [action touchedUpInside];
            }
            
            [action rolledOver];
        }else{
            [action rolledOut];
        }
    }
}

-(CGSize)sizeForMenuItems
{
    float width = 0;
    float height = 0;
    
    for (JCDropDownAction *action in self.actions)
    {
        if (action.frame.size.width > width)
            width = action.frame.size.width;
        
        height += action.frame.size.height;
    }
    
    return CGSizeMake(width, height);
}

@end