//
//  JCDropDownAction.m
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCDropDownAction.h"

@implementation JCDropDownAction
{
    UILabel *labelName;
}

+(UIFont *)defaultFont
{
    return [UIFont boldSystemFontOfSize:16];
}

+(JCDropDownAction *)dropDownActionWithName:(NSString *)actionName action:(ActionBlock)actionBlock
{
    CGSize size = [actionName sizeWithAttributes:@{NSFontAttributeName : [JCDropDownAction defaultFont]}];
    
    if (size.width < 130)
        size.width = 130;
    if (size.height < 30)
        size.height = 30;
    
    JCDropDownAction *action = [[self alloc] initWithFrame:CGRectMake(0, 0, size.width + 20, size.height)];
    
    action.name = actionName;
    action.action = actionBlock;
    
    return action;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor whiteColor];
        
        labelName = [[UILabel alloc] initWithFrame:frame];
        labelName.backgroundColor = [UIColor clearColor];
        labelName.textColor = [UIColor blackColor];
        labelName.font = [JCDropDownAction defaultFont];
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

-(void)rolledOver
{
    self.backgroundColor = [UIColor blackColor];
    labelName.textColor = [UIColor whiteColor];
}

-(void)rolledOut
{
    self.backgroundColor = [UIColor whiteColor];
    labelName.textColor = [UIColor blackColor];
}

-(void)touchedUpInside
{
    if(self.action) self.action();
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
