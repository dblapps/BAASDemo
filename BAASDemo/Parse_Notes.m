//
//  Deployd_Notes.m
//  BAASDemo
//
//  Created by David Levi on 2/8/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

#import "Notes.h"
#import <UIKit/UIKit.h>
#import <Parse/Parse.h>


NSString* NotesLoadingNotification = @"NotedLoading";
NSString* NotesLoadSucceededNotification = @"NotesLoadSucceeded";
NSString* NotesLoadFailedNotification = @"NotesLoadFailed";

NSString* NoteUpdatedNotification = @"NoteUpdatedNotification";
NSString* NoteCreatedNotification = @"NoteCreatedNotification";
NSString* NoteDeletedNotification = @"NoteDeletedNotification";

void performBlock(void(^block)(void))
{
	dispatch_async(dispatch_get_main_queue(), block);
}


@interface Note ()
@property (strong,nonatomic) PFObject* object;
@property (strong,nonatomic) NSString* name;
@property (assign,nonatomic) BOOL dirty;
@end

@implementation Note

- (instancetype) init
{
	self = [super init];
	if (self != nil) {
		_text = @"";
		_object = nil;
		_name = nil;
		_dirty = YES;
	}
	return self;
}

- (void) setText:(NSString *)text
{
	if (![text isEqualToString:_text]) {
		_text = [text copy];
		_dirty = YES;
	}
}

@end

@implementation Notes
{
	NSMutableArray* notes;
	NSMutableDictionary* notesDict;
}

+ (instancetype)sharedNotes
{
	static Notes* s_sharedNotes = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		s_sharedNotes = [[Notes alloc] init];
	});

	return s_sharedNotes;
}

- (instancetype) init
{
	self = [super init];
	if (self != nil) {
		[Parse setApplicationId:@"cvEnY7HzNIV1Vxx8Wy0NZQHq9u21Jk3i6aL0Kr9p"
					  clientKey:@"d9OwjwuRzwYHs8H1hib4C4XdgrjEE7kTp3SGNXOo"];

		notes = [NSMutableArray array];
		notesDict = [NSMutableDictionary dictionary];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

		[NSTimer scheduledTimerWithTimeInterval:NOTES_FLUSH_TO_SERVER_INTERVAL target:self selector:@selector(flushTimerFired:) userInfo:nil repeats:YES];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadingNotification object:nil];

		PFQuery* query = [PFQuery queryWithClassName:@"Notes"];
		[query orderByAscending:@"createdAt"];
		[query findObjectsInBackgroundWithBlock:^(NSArray* objects, NSError* error) {
			if (error == nil) {
				for (PFObject* object in objects) {
					Note* note = [[Note alloc] init];
					note.text = object[@"note"];
					note.object = object;
					note.name = object[@"name"];
					note.dirty = NO;
					[notes addObject:note];
					notesDict[note.name] = note;
				}
				[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadSucceededNotification object:nil];
			} else {
				[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadFailedNotification object:error];
			}
		}];
	}
	return self;
}

- (void) willResignActive:(NSNotification*)notification
{
	[self flushToCloud];
}

- (void) flushTimerFired:(NSTimer*)timer
{
	[self flushToCloud];
}

- (void) flushToCloud
{
	for (Note* note in notes) {
		if (note.dirty) {
			if (note.object == nil) {
				PFObject *object = [PFObject objectWithClassName:@"Notes"];
				object[@"note"] = note.text;
				object[@"name"] = note.name;
				[object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
					if (error == nil) {
						note.object = object;
						note.dirty = NO;
					} else {
						 NSLog(@"Error creating note: %@", error);
					}
				 }];
			} else {
				note.object[@"note"] = note.text;
				note.object[@"name"] = note.name;
				[note.object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
					if (error == nil) {
						note.dirty = NO;
					} else {
						NSLog(@"Error creating note: %@", error);
					}
				}];
			}
		}
	}
}

- (Note*) newNote
{
	Note* note = [[Note alloc] init];
	note.name = [[NSUUID UUID] UUIDString];
	[notes addObject:note];
	notesDict[note.name] = note;
	[[NSNotificationCenter defaultCenter] postNotificationName:NoteCreatedNotification object:nil];
	return note;
}

- (void) deleteNoteAtIndex:(NSInteger)index
{
	Note* note = notes[index];
	[notes removeObject:note];
	[notesDict removeObjectForKey:note.name];
	[note.object deleteInBackgroundWithBlock:^(BOOL succeeded, NSError* error) {
		if (succeeded) {
			performBlock(^() {
				[[NSNotificationCenter defaultCenter] postNotificationName:NoteDeletedNotification object:note];
			});
		} else {
			NSLog(@"Failed to delete note: %@", error);
		}
	}];
}

- (void) handlePushToken:(NSData*)token
{
	NSLog(@"PUSH TOKEN: %@", token);
	PFInstallation *currentInstallation = [PFInstallation currentInstallation];
	[currentInstallation setDeviceTokenFromData:token];
	[currentInstallation saveInBackground];
}

- (void) handlePushNotification:(NSDictionary*)info
{
	NSLog(@"got notif %@",info);
	if (info[@"n"] != nil) {
		NSString* objectId = info[@"n"][@"id"];
		NSString* type = info[@"n"][@"t"];
		if ([type isEqualToString:@"add"] || [type isEqualToString:@"upd"]) {
			PFObject* object = [PFObject objectWithoutDataWithClassName:@"Notes" objectId:objectId];
			[object fetchInBackgroundWithBlock:^(PFObject* object, NSError* error) {
				if (error == nil) {
					if (notesDict[object[@"name"]] != nil) {
						Note* note = notesDict[object[@"name"]];
						note.text = object[@"note"];
						note.object = object;
						note.dirty = NO;
						performBlock(^() {
							[[NSNotificationCenter defaultCenter] postNotificationName:NoteUpdatedNotification object:note];
						});
					} else {
						Note* note = [[Note alloc] init];
						note.text = object[@"note"];
						note.object = object;
						note.name = object[@"name"];
						note.dirty = NO;
						[notes addObject:note];
						notesDict[note.name] = note;
						performBlock(^() {
							[[NSNotificationCenter defaultCenter] postNotificationName:NoteCreatedNotification object:nil];
						});
					}
				} else {
					NSLog(@"Failed to fetch object %@", objectId);
				}
			}];
		} else if ([type isEqualToString:@"del"]) {
			for (Note* note in notes) {
				if (note.object != nil) {
					if ([note.object.objectId isEqualToString:objectId]) {
						performBlock(^() {
							[notes removeObject:note];
							notesDict[note.name] = nil;
							[[NSNotificationCenter defaultCenter] postNotificationName:NoteDeletedNotification object:note];
						});
						break;
					}
				}
			}
		}
	}
}

- (NSUInteger) count
{
	return notes.count;
}

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len
{
	return [notes countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (id) objectAtIndexedSubscript:(NSUInteger)idx
{
	return notes[idx];
}

- (NSUInteger) indexOfObject:(id)object
{
	return [notes indexOfObject:object];
}

@end
