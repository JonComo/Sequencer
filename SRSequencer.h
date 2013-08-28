//
// Copyright (c) 2013 Jon Como
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "SRClip.h"

@class SRSequencer;

typedef void (^ErrorHandlingBlock)(NSError *error);

@protocol SRSequencerDelegate <NSObject>

@optional
-(void)sequencer:(SRSequencer *)sequencer clipCountChanged:(int)count;

@end

@interface SRSequencer : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, weak) id delegate;

@property (strong, readonly) AVCaptureSession *captureSession;

@property (nonatomic, weak) UIView *viewPreview;
@property (nonatomic, weak) UICollectionView *collectionViewClips;

@property (nonatomic, strong) NSMutableArray *clips;

@property (assign, readonly) BOOL isPaused;
@property BOOL isRecording;

@property (copy, readwrite) ErrorHandlingBlock asyncErrorHandler;

-(id)initWithDelegate:(id <SRSequencerDelegate> )managerDelegate;

- (void)setupSessionWithPreset:(NSString *)preset withCaptureDevice:(AVCaptureDevicePosition)cd withTorchMode:(AVCaptureTorchMode)tm withError:(NSError **)error;

-(void)setupSessionWithDefaults;

- (void)record;
- (void)pauseRecording;
- (void)flipCamera;

- (void)reset;

- (void)finalizeRecordingToFile:(NSURL *)finalVideoLocationURL withVideoSize:(CGSize)videoSize withPreset:(NSString *)preset withCompletionHandler:(void (^)(NSError *error))completionHandler;

//Clip Modifications

-(void)duplicateClipAtIndex:(NSInteger)index;
-(void)removeClipAtIndex:(NSInteger)index;

@end
