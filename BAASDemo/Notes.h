//
//  Notes.h
//  BAASDemo
//
//  Created by David Levi on 2/1/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

//#ifdef USE_CLOUDKIT
//#import "CloudKit_Notes.h"
//#endif

//#ifdef USE_DEPLOYD
//#import "Deployd_Notes.h"
//#endif

#import <Foundation/Foundation.h>

#define NOTES_FLUSH_TO_SERVER_INTERVAL (3.0f)

extern NSString* NotesLoadingNotification;
extern NSString* NotesLoadSucceededNotification;
extern NSString* NotesLoadFailedNotification;

extern NSString* NoteUpdatedNotification;
extern NSString* NoteCreatedNotification;
extern NSString* NoteDeletedNotification;


@interface Note : NSObject

@property (strong,nonatomic) NSString* text;

@end


@interface Notes : NSObject <NSFastEnumeration>

@property (readonly) NSUInteger count;

+ (instancetype)sharedNotes;

- (Note*) newNote;

- (void) deleteNoteAtIndex:(NSInteger)index;

- (void) handlePushToken:(NSData*)token;
- (void) handlePushNotification:(NSDictionary*)info;

- (id) objectAtIndexedSubscript:(NSUInteger)idx;
- (NSUInteger) indexOfObject:(id)object;

@end
