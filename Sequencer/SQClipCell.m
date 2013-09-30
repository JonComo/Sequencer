//
//  SQClipCell.m
//  Sequencer
//
//  Created by Jon Como on 8/31/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipCell.h"

#import <QuartzCore/QuartzCore.h>

#import "SRClip.h"

@interface SQClipCell ()

@end

@implementation SQClipCell

-(void)setClip:(SRClip *)clip
{
    _clip = clip;
    
    [self clearSubviews];
    [self layoutThumbs];
    [self showLength];
    
    self.layer.borderWidth = 2;
    
    if (clip.isSelected){
        self.layer.borderColor = [UIColor whiteColor].CGColor;
    }else{
        self.layer.borderColor = [UIColor colorWithWhite:0.15 alpha:1].CGColor;
    }
}

-(void)clearSubviews
{
    for (UIView *subview in self.subviews)
        [subview removeFromSuperview];
}

-(void)showLength
{
    NSString *length = [NSString stringWithFormat:@"%.2f", CMTimeGetSeconds(self.clip.asset.duration)];
    
    UIFont *font = [UIFont boldSystemFontOfSize:8];
    CGSize labelSize = [length sizeWithAttributes:@{NSFontAttributeName: font}];
    
    labelSize = CGSizeMake(labelSize.width + 4, labelSize.height + 4); //padding
    
    UILabel *labelLength = [[UILabel alloc] initWithFrame:CGRectMake(self.clip.timelineSize.width - labelSize.width - 2, self.clip.timelineSize.height - labelSize.height - 2, labelSize.width, labelSize.height)];
    labelLength.font = font;
    labelLength.text = length;
    labelLength.textAlignment = NSTextAlignmentCenter;
    [labelLength setMinimumScaleFactor:0.2];
    
    [labelLength setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.8]];
    [labelLength setTextColor:[UIColor whiteColor]];
    
    [self addSubview:labelLength];
}

-(void)layoutThumbs
{
    float x = 0;
    
    CGSize size = self.clip.timelineSize;
    CGSize thumbnailSize = CGSizeMake(size.height, size.height);
    
    for (UIImage *thumb in self.clip.thumbnails)
    {
        UIImageView *thumbImageView = [[UIImageView alloc] initWithImage:thumb];
        thumbImageView.frame = CGRectMake(x, 0, thumbnailSize.width, thumbnailSize.height);
        thumbImageView.contentMode = UIViewContentModeScaleAspectFit;
        
        x += thumbnailSize.width;
        
        [self addSubview:thumbImageView];
    }
}

@end