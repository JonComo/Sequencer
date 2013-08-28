//
//  JCActionSheetManager.h
//  Underground
//
//  Created by Jon Como on 5/8/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ButtonHit)(NSInteger buttonIndex);
typedef void (^MediaCompletion)(UIImage *image, NSURL *movieURL);

@interface JCActionSheetManager : NSObject

@property (nonatomic, weak) UIViewController *delegate;

+(JCActionSheetManager *)sharedManager;

-(void)actionSheetInView:(UIView *)view withTitle:(NSString *)title buttons:(NSArray *)buttons cancel:(NSString *)cancel destructive:(NSString *)destructive completion:(ButtonHit)block;
-(void)imagePickerInView:(UIView *)view onlyLibrary:(BOOL)onlyLibrary completion:(MediaCompletion)block;

@end