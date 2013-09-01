//
//  JCActionSheetManager.m
//  Underground
//
//  Created by Jon Como on 5/8/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCActionSheetManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

@interface JCActionSheetManager () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    ButtonHit buttonCompletion;
    MediaCompletion mediaCompletion;
    BOOL shouldSave;
}

@end

@implementation JCActionSheetManager

+(JCActionSheetManager *)sharedManager
{
    static JCActionSheetManager *sharedManager;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    
    return sharedManager;
}

-(void)actionSheetInView:(UIView *)view withTitle:(NSString *)title buttons:(NSArray *)buttons cancel:(NSString *)cancel destructive:(NSString *)destructive completion:(ButtonHit)block
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:nil destructiveButtonTitle:destructive otherButtonTitles:nil];
    actionSheet.tag = 100;
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    actionSheet.delegate = self;
    buttonCompletion = block;
    
    for (NSString *buttonName in buttons){
        [actionSheet addButtonWithTitle:buttonName];
    }
    
    if (cancel) [actionSheet addButtonWithTitle:cancel];
    
    if (actionSheet.numberOfButtons > 1)
        [actionSheet setCancelButtonIndex:actionSheet.numberOfButtons-1];
    
    [actionSheet showInView:view];
}

-(void)imagePickerInView:(UIView *)view onlyLibrary:(BOOL)onlyLibrary completion:(MediaCompletion)block
{
    mediaCompletion = block;
    
    NSString *photos = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] ? @"Photo Library" : nil;
    NSString *camera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ? @"Camera" : nil;
    
    if (onlyLibrary && photos)
    {
        [self imagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        return;
    }
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Choose source" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:photos, camera, nil];
    actionSheet.tag = 200;
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    actionSheet.delegate = self;
    
    [actionSheet showInView:view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (actionSheet.tag) {
        case 100:
            if (buttonCompletion) buttonCompletion(buttonIndex);
            break;
            
        case 200:
            switch (buttonIndex) {
                case 0:
                    //photo lib
                    [self imagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                    break;
                    
                case 1:
                    //camera
                    [self imagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
                    shouldSave = YES;
                    break;
                    
                default:
                    break;
            }
            break;
            
        default:
            break;
    }
}

-(void)imagePickerWithSourceType:(UIImagePickerControllerSourceType)source
{
    if (![UIImagePickerController isSourceTypeAvailable:source])
        return;
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    [picker setSourceType:source];
    picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:source];
    
    
    
    if ([picker.mediaTypes containsObject:(id)kUTTypeMovie] && source == UIImagePickerControllerSourceTypeCamera)
        [picker setCameraCaptureMode:UIImagePickerControllerCameraCaptureModeVideo];
    
    //[picker setAllowsEditing:YES];
    
    picker.delegate = self;
    
    [self.delegate presentViewController:picker animated:NO completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    NSURL *movieURL = info[UIImagePickerControllerMediaURL];
    
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera)
    {
        //Save if from the camera
        if (image) UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        if (movieURL) UISaveVideoAtPathToSavedPhotosAlbum([movieURL path], nil, nil, nil);
    }
    
    [picker dismissViewControllerAnimated:NO completion:^{
        if (mediaCompletion) mediaCompletion(image, movieURL);
    }];
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
