//
// Copyright (c) 2013 Jon Como
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "JCMoviePlayer.h"

#import "SRClip.h"

#define SRSequenceRefreshPreview @"sequenceRefreshPreview"

@class SRSequencer;
@class SQTimeline;

typedef void (^ErrorHandlingBlock)(NSError *error);

@protocol SRSequencerDelegate <NSObject>

@optional
-(void)sequencer:(SRSequencer *)sequencer isRecording:(BOOL)recording;
-(void)sequencer:(SRSequencer *)sequencer isZoomedIn:(BOOL)isZoomed;

@end

@interface SRSequencer : NSObject <AVCaptureFileOutputRecordingDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) id delegate;

@property (strong, readonly) AVCaptureSession *captureSession;
@property (strong, nonatomic) JCMoviePlayer *player;

@property (strong, nonatomic) NSString *exportPreset;

@property (nonatomic, weak) UIView *viewPreview;
@property (nonatomic, weak) SQTimeline *timeline;
@property (nonatomic, strong) AVComposition *composition;

@property (nonatomic, assign) CMTime duration;
@property (nonatomic, assign) CGSize videoSize;

@property (nonatomic, strong) NSMutableArray *clips;

@property (assign, readonly) BOOL isPaused;
@property BOOL isRecording;
@property BOOL isZoomed;

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

- (void)showPreview;
- (void)hidePreview;

- (void)play;
- (void)stop;

- (void)reset;

- (void)finalizeClips:(NSArray *)clipsCombining toFile:(NSURL *)finalVideoLocationURL withPreset:(NSString *)preset progress:(void (^)(float progress))progress withCompletionHandler:(ErrorHandlingBlock)completionHandler;

//Camera control
-(void)setFocusPoint:(CGPoint)point;
-(void)setExposurePoint:(CGPoint)point;
-(void)lock;

//Clip Modifications

-(void)deleteSelectedClips;
-(void)duplicateSelectedClips;
-(void)consolidateSelectedClipsProgress:(void (^)(float))progress completion:(void (^)(SRClip *))consolidateHandler;

-(void)removeClip:(SRClip *)clip;
-(void)addClipFromURL:(NSURL *)url;
-(void)addClip:(SRClip *)clip;

@end
