//
//  SQRecordViewController.m
//  Sequencer
//
//  Created by Jon Como on 8/27/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQRecordViewController.h"
#import "SRSequencer.h"

#import "MBProgressHUD.h"
#import "Macros.h"

#import "JCActionSheetManager.h"

#import <QuartzCore/QuartzCore.h>

#import "SQClipTimeStretch.h"

#import "SQClipCell.h"

#import "SQTrimViewController.h"

#import "SQTimeline.h"

#import "SQVideoComposer.h"

#import "JCDropDown.h"

#import "SQAlertView.h"

//Effects
#import "SQEffectScramble.h"

#define TIPRecord @"TAP TO SET FOCUS"
#define TIPRecordStop @"TAP TO SET EXPOSURE"

@interface SQRecordViewController () <SRSequencerDelegate, UIAlertViewDelegate>
{
    SRSequencer *sequence;
    
    __weak IBOutlet JCDropDown *dropDownClip;
    __weak IBOutlet JCDropDown *dropDownCam;
    __weak IBOutlet JCDropDown *dropDownFile;
    
    __weak IBOutlet UIButton *buttonRecord;
    __weak IBOutlet UIButton *buttonPlay;
    
    __weak IBOutlet UIView *viewPreview;
    __weak IBOutlet SQTimeline *timeline;
    
    BOOL setFocus;
    BOOL rePitch;
}

@end

@implementation SQRecordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    buttonRecord.backgroundColor = [UIColor redColor];
    buttonRecord.layer.cornerRadius = 22;
    buttonPlay.enabled = NO;
    buttonPlay.alpha = 0;
    
    sequence = [[SRSequencer alloc] initWithDelegate:self];
    sequence.timeline = timeline;
    sequence.viewPreview = viewPreview;
    
    [viewPreview addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)]];
    
    [self initInterface];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [timeline frameUpdated];
    
    if (!sequence.captureSession)
        [sequence setupSessionWithDefaults];
    
    if (sequence.captureSession.isInterrupted || !sequence.captureSession.isRunning)
        [sequence.captureSession startRunning];
    
    
    [timeline reloadData];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [sequence.captureSession stopRunning];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

-(BOOL)shouldAutorotate
{
    return YES;
}

-(void)dealloc
{
    NSLog(@"Recorder Removed");
}

-(void)initInterface
{
    [self clipActions];
    [self cameraActions];
    [self fileActions];
}

-(JCDropDown *)transformActions
{
    JCDropDown *flipH = [JCDropDown dropDownActionWithName:@"FLIP H" action:^{
        SRClip *selected = [timeline lastSelectedClip];
        if (!selected){
            [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
            return;
        }
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(-1, 1);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, 0));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDown *flipV = [JCDropDown dropDownActionWithName:@"FLIP V" action:^{
        SRClip *selected = [timeline lastSelectedClip];
        if (!selected){
            [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
            return;
        }
        
        AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
        
        CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
        transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0, videoTrack.naturalSize.height));
        
        [self applyTransform:transform toClip:selected];
    }];
    
    JCDropDown *scaleByX = [JCDropDown dropDownActionWithName:@"SCALE X" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO SCALE" hideAfterDelay:YES];
            return;
        }
        
        SQAlertView * alert = [[SQAlertView alloc] initWithTitle:@"SCALE BY RATIO:" message:nil delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"SCALE", nil];
        
        alert.clip = lastSelected;
        
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *textfield = [alert textFieldAtIndex:0];
        textfield.placeholder = @"0.1 - 10.0";
        textfield.keyboardAppearance = UIKeyboardAppearanceDark;
        textfield.keyboardType = UIKeyboardTypeDecimalPad;
        
        alert.action = SQAlertViewActionScale;
        
        [alert show];
    }];
    
    JCDropDown *scaleDown = [JCDropDown dropDownActionWithName:@"SCALE / 2" action:^{
        [self scaleClipByRatio:0.5];
    }];
    
    JCDropDown *scaleUp = [JCDropDown dropDownActionWithName:@"SCALE X 2" action:^{
        [self scaleClipByRatio:2];
    }];
    
    JCDropDown *transformActions = [JCDropDown dropDownActionWithName:@"SCALE" action:nil];
    transformActions.actions = [@[flipH, flipV, scaleByX, scaleDown, scaleUp] mutableCopy];
    
    return transformActions;
}

-(void)clipActions
{
    //Clip actions
    
    JCDropDown *duplicate = [JCDropDown dropDownActionWithName:@"DUPLICATE" action:^{
        if ([timeline selectedClips].count == 0){
            [self showHUDWithTitle:@"SELECT CLIPS TO DUPLICATE" hideAfterDelay:YES];
            return;
        }
        
        [self showHUDWithTitle:@"DUPLICATING" hideAfterDelay:NO];
        [sequence duplicateSelectedClipsCompletion:^{
            [self hideHUD];
        }];
    }];
    
    JCDropDown *delete = [JCDropDown dropDownActionWithName:@"DELETE" action:^{
        if ([timeline selectedClips].count == 0){
            [self showHUDWithTitle:@"SELECT CLIPS TO DELETE" hideAfterDelay:YES];
            return;
        }
        
        [sequence deleteSelectedClips];
    }];
    
    JCDropDown *join = [JCDropDown dropDownActionWithName:@"JOIN" action:^{
        [self join];
    }];
    
    JCDropDown *cut = [JCDropDown dropDownActionWithName:@"CUT" action:^{
        //find clip at time, reexport two portions of it, before and after cut.
        SRClip *clipToCut = [timeline clipAtTime:timeline.currentTime];
        
        if (!clipToCut){
            [self showHUDWithTitle:@"SCROLL OVER CLIP TO CUT" hideAfterDelay:YES];
            return;
        }
        
        [self showHUDWithTitle:@"CUTTING" hideAfterDelay:NO];
        
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:clipToCut.URL options:nil];
        
        NSUInteger index = [sequence.clips indexOfObject:clipToCut];
        
        CMTimeRange startRange = CMTimeRangeMake(kCMTimeZero, CMTimeSubtract(timeline.currentTime, clipToCut.positionInComposition.start));
        CMTimeRange endRange = CMTimeRangeMake(startRange.duration, CMTimeSubtract(asset.duration, startRange.duration));
        
        NSLog(@"StartRange: %f %f EndRange: %f %f", CMTimeGetSeconds(startRange.start), CMTimeGetSeconds(startRange.duration), CMTimeGetSeconds(endRange.start), CMTimeGetSeconds(endRange.duration));
        
        NSMutableArray *clipsToAdd = [NSMutableArray array];
        
        [self exportTimeRange:startRange ofClip:clipToCut completion:^(SRClip *clip) {
            [clipsToAdd addObject:clip];
            
            [self exportTimeRange:endRange ofClip:clipToCut completion:^(SRClip *clip) {
                [clipsToAdd addObject:clip];
                
                [sequence insertClips:clipsToAdd atIndex:index + 1];
                
                [sequence removeClip:clipToCut];
                
                [timeline reloadData];
                
                [self hideHUD];
            }];
        }];
    }];
    
    dropDownClip.actions = [@[[self effectActions], [self transformActions], [self timeActions], join, cut, delete, duplicate] mutableCopy];
}

-(JCDropDown *)effectActions
{
    JCDropDown *compress = [JCDropDown dropDownActionWithName:@"COMPRESS" action:^{
        if ([timeline selectedClips].count == 0){
            [self showHUDWithTitle:@"SELECT CLIPS TO COMPRESS" hideAfterDelay:YES];
            return;
        }
        
        [self exportClip:[timeline lastSelectedClip] withPreset:AVAssetExportPresetLowQuality completion:^(SRClip *exportedClip) {
            [exportedClip generateThumbnailsCompletion:^(NSError *error) {
                if (error) return;
                [sequence addClip:exportedClip];
                [timeline reloadData];
            }];
        }];
    }];
    
    JCDropDown *scramble = [JCDropDown dropDownActionWithName:@"SCRAMBLE" action:^{
        if ([timeline selectedClips].count == 0){
            [self showHUDWithTitle:@"SELECT CLIPS TO SCRAMBLE" hideAfterDelay:YES];
            return;
        }
        
        [self showHUDWithTitle:@"Scrambling" hideAfterDelay:NO];
        
        [[[SQEffectScramble alloc] initWithClip:[timeline lastSelectedClip]] renderEffectCompletion:^(SRClip *output) {
            [self hideHUD];
            [sequence addClip:output];
            [timeline reloadData];
        }];
    }];
    
    JCDropDown *effectActions = [JCDropDown dropDownActionWithName:@"EFFECTS" action:nil];
    effectActions.actions = [@[compress, scramble] mutableCopy];
    
    return effectActions;
}

-(JCDropDown *)timeActions
{
    //Time actions
    
//    JCDropDown *trim = [JCDropDown dropDownActionWithName:@"TRIM" action:^{
//        [self trim];
//    }];
    
    JCDropDown *retimeSlow = [JCDropDown dropDownActionWithName:@"RETIME SLOW" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO RETIME" hideAfterDelay:YES];
            return;
        }
        
        [self retimeClip:lastSelected multiple:2.0];
    }];
    
    JCDropDown *retimeFast = [JCDropDown dropDownActionWithName:@"RETIME FAST" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO RETIME" hideAfterDelay:YES];
            return;
        }
        
        [self retimeClip:lastSelected multiple:0.5];
    }];
    
    JCDropDown *retimeCustom = [JCDropDown dropDownActionWithName:@"RETIME X" action:^{
        SRClip *lastSelected = [timeline lastSelectedClip];
        if (!lastSelected){
            [self showHUDWithTitle:@"SELECT CLIP TO RETIME" hideAfterDelay:YES];
            return;
        }
        
        SQAlertView * alert = [[SQAlertView alloc] initWithTitle:@"NEW DURATION" message:nil delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"RETIME", nil];
        
        alert.clip = lastSelected;
        
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField *textfield = [alert textFieldAtIndex:0];
        textfield.placeholder = @"SECONDS";
        textfield.keyboardAppearance = UIKeyboardAppearanceDark;
        textfield.keyboardType = UIKeyboardTypeDecimalPad;
        alert.action = SQAlertViewActionRetime;
        [alert show];
    }];
    
    JCDropDown *retimePitch = [JCDropDown dropDownActionWithName:@"REPITCH NO" action:nil];
    
    __weak JCDropDown *weakPitch = retimePitch;
    [retimePitch setAction:^{
        rePitch = !rePitch;
        weakPitch.name = rePitch ? @"REPITCH YES" : @"REPITCH NO";
    }];
    
    JCDropDown *timeActions = [JCDropDown dropDownActionWithName:@"TIME" action:nil];

    timeActions.actions = [@[retimePitch, retimeSlow, retimeFast, retimeCustom] mutableCopy];
    
    return timeActions;
}

-(void)cameraActions
{
    //Cam actions
    
    JCDropDown *setFocusAction = [JCDropDown dropDownActionWithName:@"SET FOCUS" action:^{
        setFocus = YES;
    }];
    
    JCDropDown *setExposureAction = [JCDropDown dropDownActionWithName:@"SET EXPOSURE" action:^{
        setFocus = NO;
    }];
    
    JCDropDown *session1080 = [JCDropDown dropDownActionWithName:@"1920 X 1080" action:^{
        [sequence setupSessionWithPreset:AVCaptureSessionPreset1920x1080 withCaptureDevice:AVCaptureDevicePositionBack withError:nil];
    }];
    
    JCDropDown *session720 = [JCDropDown dropDownActionWithName:@"1280 X 720" action:^{
        [sequence setupSessionWithPreset:AVCaptureSessionPreset1280x720 withCaptureDevice:AVCaptureDevicePositionBack withError:nil];
    }];
    
    JCDropDown *session480 = [JCDropDown dropDownActionWithName:@"640 X 480" action:^{
        [sequence setupSessionWithPreset:AVCaptureSessionPreset640x480 withCaptureDevice:AVCaptureDevicePositionBack withError:nil];
    }];
    
    JCDropDown *flipCamera = [JCDropDown dropDownActionWithName:@"FLIP" action:^{
        [sequence flipCamera];
    }];
    
    JCDropDown *settings = [JCDropDown dropDownActionWithName:@"SETTINGS" action:nil];
    
    NSMutableArray *settingsActions = [NSMutableArray array];
    
    if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront])
        [settingsActions addObject:flipCamera];
    
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset640x480])
        [settingsActions insertObject:session480 atIndex:0];
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset1280x720])
        [settingsActions insertObject:session720 atIndex:0];
    if ([[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPreset1920x1080])
        [settingsActions insertObject:session1080 atIndex:0];
    
    settings.actions = settingsActions;
    
    dropDownCam.actions = [@[settings, setFocusAction, setExposureAction] mutableCopy];
}

-(void)fileActions
{
    //File actions
    
    JCDropDown *import = [JCDropDown dropDownActionWithName:@"IMPORT" action:^{
        [self import];
    }];
    
    JCDropDown *close = [JCDropDown dropDownActionWithName:@"CLOSE" action:^{
        [self close];
    }];
    
    JCDropDown *save = [JCDropDown dropDownActionWithName:@"SAVE" action:^{
        [self save];
    }];
    
    dropDownFile.actions = [@[import, close, save] mutableCopy];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    SQAlertView *alert = (SQAlertView *)alertView;
    
    if (alert.action == SQAlertViewActionRetime)
    {
        //retime alert
        UITextField *textfield = [alertView textFieldAtIndex:0];
        float newDuration = [textfield.text floatValue];
        
        SRClip *clip = alert.clip;
        
        float clipDuration = CMTimeGetSeconds(clip.positionInComposition.duration);
        
        float ratio = newDuration / clipDuration;
        
        [self retimeClip:clip multiple:ratio];
    }else if (alert.action == SQAlertViewActionClose)
    {
        //close alert
        if (buttonIndex == 1){
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }else if (alert.action == SQAlertViewActionScale)
    {
        UITextField *textfield = [alertView textFieldAtIndex:0];
        float newScale = [textfield.text floatValue];
        
        [self scaleClipByRatio:newScale];
    }
}

#pragma SequenceDelegate

-(void)sequencer:(SRSequencer *)sequencer isRecording:(BOOL)recording
{
    buttonPlay.enabled = !recording;
    buttonPlay.alpha = recording ? 0 : 1;
    
    [UIView animateWithDuration:0.2 animations:^{
        if (recording){
            buttonRecord.backgroundColor = [UIColor whiteColor];
            buttonRecord.layer.cornerRadius = 0;
            buttonRecord.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1);
        }else{
            buttonRecord.backgroundColor = [UIColor redColor];
            buttonRecord.layer.cornerRadius = 22;
            buttonRecord.layer.transform = CATransform3DMakeScale(1, 1, 1);
        }
    }];
}

-(void)sequencer:(SRSequencer *)sequencer isZoomed:(BOOL)zoomed
{
    [UIView animateWithDuration:0.2 animations:^{
        timeline.layer.transform = CATransform3DMakeTranslation(0, zoomed ? 40 : 0, 0);
    }];
}

-(void)sequencer:(SRSequencer *)sequencer isPlaying:(BOOL)playing
{
    [buttonPlay setTitle:playing ? @"STOP" : @"PLAY" forState:UIControlStateNormal];
}

#pragma UIActions

-(void)viewTapped:(UITapGestureRecognizer *)tap
{
    CGPoint viewLocation = [tap locationInView:tap.view];
    
    if (setFocus)
    {
        [sequence setFocusPoint:viewLocation];
    }else{
        [sequence setExposurePoint:viewLocation];
    }
}

- (void)close
{
    SQAlertView *closeAlert = [[SQAlertView alloc] initWithTitle:@"CLOSE PROJECT?" message:nil delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"CLOSE", nil];
    closeAlert.action = SQAlertViewActionClose;
    [closeAlert show];
}

- (IBAction)record:(id)sender
{
    if (sequence.isRecording){
        [sequence pauseRecording];
    }else{
        [sequence record];
    }
}

- (IBAction)preview:(id)sender
{
    if (sequence.player.superview){
        [sequence hidePreview];
        [sequence stop];
    }else{
        [sequence refreshPreview];
        [sequence showPreview];
        [sequence play];
    }
}

- (void)save
{
    [self showHUDWithTitle:@"RENDERING" hideAfterDelay:NO];
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:sequence.clips toFile:outputURL withPreset:sequence.exportPreset progress:^(float progress) {
        [self showProgress:progress];
    } withCompletionHandler:^(NSError *error) {
        [self hideHUD];
        
        if (error) return;
        
        UISaveVideoAtPathToSavedPhotosAlbum([outputURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }];
}

//clip actions

- (void)retimeClip:(SRClip *)clip multiple:(float)amount
{
    SRClip *lastSelected = [timeline lastSelectedClip];
    if (!lastSelected) return;
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:lastSelected.URL options:nil];
    [self showHUDWithTitle:[NSString stringWithFormat:@"RETIMING %.2f X %.1f", CMTimeGetSeconds(asset.duration), amount] hideAfterDelay:NO];
    
    [SQClipTimeStretch stretchClip:lastSelected byAmount:amount rePitch:rePitch completion:^(SRClip *stretchedClip) {
        [self hideHUD];
        [sequence addClip:stretchedClip];
        [timeline reloadData];
    }];
}

- (void)import
{
    [sequence.captureSession stopRunning];
    
    [[JCActionSheetManager sharedManager] setDelegate:self];
    [[JCActionSheetManager sharedManager] imagePickerInView:self.view onlyLibrary:YES completion:^(UIImage *image, NSURL *movieURL) {
        
        [sequence.captureSession startRunning];
        
        [sequence addClipFromURL:movieURL];
        [timeline reloadData];
    }];
}

- (void)trim
{
    if ([timeline selectedClips].count == 0){
        [self showHUDWithTitle:@"SELECT CLIPS TO TRIM" hideAfterDelay:YES];
        return;
    }
    
    SQTrimViewController *trimVC = [self.storyboard instantiateViewControllerWithIdentifier:@"trimVC"];
    
    SRClip *selectedClip;
    
    for (SRClip *clip in sequence.clips){
        if (clip.isSelected) selectedClip = clip;
    }
    
    if (!selectedClip) return;
    
    trimVC.clip = selectedClip;
    
    trimVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self presentViewController:trimVC animated:YES completion:nil];
}

- (void)join
{
    if ([timeline selectedClips].count < 2){
        [self showHUDWithTitle:@"SELECT 2 OR MORE CLIPS TO JOIN" hideAfterDelay:YES];
        return;
    }
    
    [self showHUDWithTitle:@"JOINING" hideAfterDelay:NO];
    
    [sequence consolidateSelectedClipsProgress:^(float progress) {
        [self showProgress:progress];
    } completion:^(SRClip *consolidated) {
        [self hideHUD];
        
        [consolidated generateThumbnailsCompletion:^(NSError *error) {
            if (error){
                [self showHUDWithTitle:@"ERROR" hideAfterDelay:YES];
                return;
            }
            
            [sequence addClip:consolidated];
            [timeline reloadData];
        }];
    }];
}

-(void)scaleClipByRatio:(float)ratio
{
    SRClip *selected = [timeline lastSelectedClip];
    if (!selected){
        [self showHUDWithTitle:@"SELECT CLIP TO TRANSFORM" hideAfterDelay:YES];
        return;
    }
    
//    AVAssetTrack *videoTrack = [selected trackWithMediaType:AVMediaTypeVideo];
//    
//    float translateRatio = 1 - ratio;
//    CGPoint translateAmount = CGPointMake(videoTrack.naturalSize.width * translateRatio, videoTrack.naturalSize.height * translateRatio);
//    
//    CGAffineTransform transform = CGAffineTransformMakeTranslation(translateAmount.x, translateAmount.y);
//    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(ratio, ratio));
    
    CGAffineTransform transform = CGAffineTransformMakeScale(ratio, ratio);
    
    [self applyTransform:transform toClip:selected];
}

-(void)applyTransform:(CGAffineTransform)transform toClip:(SRClip *)clip
{
    [clip setModifyLayerInstruction:^(AVMutableVideoCompositionLayerInstruction *layerInstruction, CMTimeRange range) {
        [layerInstruction setTransform:transform atTime:range.start];
    }];
    
    [self exportClip:clip completion:^{
        [clip setModifyLayerInstruction:nil];
    }];
}

-(void)exportClip:(SRClip *)clip completion:(void(^)(void))block
{
    [self exportClip:clip withPreset:sequence.exportPreset completion:^(SRClip *exportedClip) {
        [exportedClip generateThumbnailsCompletion:^(NSError *error) {
            
            if (!error){
                [sequence addClip:exportedClip];
                [timeline reloadData];
            }
            
            if (block) block();
        }];
    }];
}

-(void)exportTimeRange:(CMTimeRange)range ofClip:(SRClip *)clip completion:(void(^)(SRClip *clip))block
{
    NSDictionary *info = [SQVideoComposer timeRange:range ofClip:clip];
    
    NSURL *outputURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [[SQVideoComposer new] exportCompositionInfo:info toURL:outputURL withPreset:sequence.exportPreset progress:^(float progress) {
    } withCompletionHandler:^(NSError *error) {
        SRClip *clip = [[SRClip alloc] initWithURL:outputURL];
        
        [clip generateThumbnailsCompletion:^(NSError *error) {
            if (!error && block) block(clip);
        }];
    }];
}

-(void)exportClip:(SRClip *)clip withPreset:(NSString *)preset completion:(void(^)(SRClip *exportedClip))block
{
    [self showHUDWithTitle:@"EXPORTING" hideAfterDelay:NO];
    
    NSURL *exportURL = [SRClip uniqueFileURLInDirectory:DOCUMENTS];
    
    [sequence finalizeClips:@[clip] toFile:exportURL withPreset:preset progress:^(float progress) {
        [self showProgress:progress];
    } withCompletionHandler:^(NSError *error)
    {
        [self hideHUD];
        
        if (error)
        {
            [self showHUDWithTitle:@"ERROR" hideAfterDelay:YES];
            if (block) block(nil);
            return;
        }
        
        SRClip *exported = [[SRClip alloc] initWithURL:exportURL];
        
        if (block) block(exported);
    }];
}

-(void)showHUDWithTitle:(NSString *)title hideAfterDelay:(BOOL)hide
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = hide ? MBProgressHUDModeText : MBProgressHUDModeIndeterminate;
    hud.labelText = title;
    
    if (hide)
        [hud hide:YES afterDelay:1];
}

-(void)hideHUD
{
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}

-(void)showProgress:(float)progress
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    
    if (hud.mode != MBProgressHUDModeDeterminate)
        hud.mode = MBProgressHUDModeDeterminate;
    
    hud.progress = progress;
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *) contextInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [hud setMode:MBProgressHUDModeText];
        hud.labelText = !error ? @"SAVED TO PHOTO LIBRARY" : @"ERROR SAVING";
        
        [hud hide:YES afterDelay:2];
    });
}

@end
