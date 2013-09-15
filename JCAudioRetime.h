//
//  JCAudioRetime.h
//  iPhoneTest
//
//  Created by Jon Como on 9/15/13.
//
//

#import <Foundation/Foundation.h>

#import "EAFRead.h"
#import "EAFWrite.h"

@interface JCAudioRetime : NSObject
{
	EAFRead *reader;
	EAFWrite *writer;
}

@property (readonly) EAFRead *reader;

-(void)retimeAudioAtURL:(NSURL *)originalURL withRatio:(float)ratio rePitch:(BOOL)rePitch completion:(void(^)(NSURL *outURL))block;

@end
