//
//  SQClipViewController.m
//  Sequencer
//
//  Created by Jon Como on 9/13/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipViewController.h"

#import "SRClip.h"

#import <AVFoundation/AVFoundation.h>

@interface SQClipViewController () <UIVideoEditorControllerDelegate, UINavigationControllerDelegate>

@end

@implementation SQClipViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)trim:(id)sender
{
    UIVideoEditorController *editorVC = [[UIVideoEditorController alloc] init];
    
    editorVC.delegate = self;
    
    editorVC.videoPath = [self.clip.URL path];
    
    [self presentViewController:editorVC animated:YES completion:nil];
}

-(void)videoEditorController:(UIVideoEditorController *)editor didFailWithError:(NSError *)error
{
    
}

-(void)videoEditorController:(UIVideoEditorController *)editor didSaveEditedVideoToPath:(NSString *)editedVideoPath
{
    
}

-(void)videoEditorControllerDidCancel:(UIVideoEditorController *)editor
{
    
}

@end
