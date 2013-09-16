//
// Copyright (c) 2013 Jon Como
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "SRClip.h"

@class SRSequencer;
@class SQTimeline;

typedef void (^ErrorHandlingBlock)(NSError *error);

@protocol SRSequencerDelegate <NSObject>

@optional
-(void)sequencer:(SRSequencer *)sequencer clipCountChanged:(int)count;

-(void)sequencer:(SRSequencer *)sequencer isRecording:(BOOL)recording;

@end

@interface SRSequencer : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, weak) id delegate;

@property (strong, readonly) AVCaptureSession *captureSession;

@property (nonatomic, weak) UIView *viewPreview;
@property (nonatomic, weak) SQTimeline *collectionViewClips;

@property (nonatomic, strong) NSMutableArray *clips;

@property (assign, readonly) BOOL isPaused;
@property BOOL isRecording;

@property (copy, readwrite) ErrorHandlingBlock asyncErrorHandler;

@property BOOL lockExposure;
@property BOOL lockFocus;

@property (strong, nonatomic) UIView *viewForFocusPoint;
@property (strong, nonatomic) UIView *viewForExposurePoint;

-(id)initWithDelegate:(id <SRSequencerDelegate> )managerDelegate;

- (void)setupSessionWithPreset:(NSString *)preset withCaptureDevice:(AVCaptureDevicePosition)cd withError:(NSError **)error;
-(void)setupSessionWithDefaults;

- (void)record;
- (void)pauseRecording;
- (void)flipCamera;

- (void)preview;

- (void)reset;

- (void)finalizeClips:(NSArray *)clipsCombining toFile:(NSURL *)finalVideoLocationURL withCompletionHandler:(ErrorHandlingBlock)completionHandler;

//Camera control
-(void)setFocusPoint:(CGPoint)point;
-(void)setExposurePoint:(CGPoint)point;
-(void)lock;

//Clip Modifications

-(void)deleteSelectedClips;
-(void)duplicateSelectedClips;
-(void)consolidateSelectedClipsCompletion:(void(^)(SRClip *consolidated))consolidateHandler;


-(SRClip *)duplicateClip:(SRClip *)clip;
-(void)removeClip:(SRClip *)clip;
-(void)addClipFromURL:(NSURL *)url;
-(void)addClip:(SRClip *)clip;

@end
