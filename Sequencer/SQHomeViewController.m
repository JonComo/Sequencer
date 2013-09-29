//
//  SQHomeViewController.m
//  Sequencer
//
//  Created by Jon Como on 8/28/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQHomeViewController.h"

#import "Macros.h"

@interface SQHomeViewController ()

@end

@implementation SQHomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self clearFilesAtPath:NSTemporaryDirectory()];
    [self clearFilesAtPath:DOCUMENTS];
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
