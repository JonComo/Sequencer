//
//  SQHomeViewController.m
//  Sequencer
//
//  Created by Jon Como on 8/28/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQHomeViewController.h"

#import "SQCameraEffectView.h"

#import "Macros.h"

@interface SQHomeViewController ()
{
    __weak IBOutlet SQCameraEffectView *cameraEffectView;
}

@end

@implementation SQHomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self clearFilesAtPath:NSTemporaryDirectory()];
    [self clearFilesAtPath:DOCUMENTS];
    
    [cameraEffectView startAnimating];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [cameraEffectView stopAnimating];
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(BOOL)shouldAutorotate
{
    return YES;
}

-(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

-(void)clearFilesAtPath:(NSString *)path
{
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    for (NSString *filename in files)
    {
        NSLog(@"FILE: %@", filename);
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", path, filename] error:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
