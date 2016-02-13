//
//  Deployd_Notes.m
//  BAASDemo
//
//  Created by David Levi on 2/8/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

#import "Notes.h"
#import <UIKit/UIKit.h>
#import "AFNetworking/AFNetworking.h"


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
@property (strong,nonatomic) NSString* recordID;
@property (strong,nonatomic) NSString* name;
@property (assign,nonatomic) BOOL dirty;
@end

@implementation Note

- (instancetype) init
{
	self = [super init];
	if (self != nil) {
		_text = @"";
		_recordID = nil;
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
	AFHTTPSessionManager* sessionManager;
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
		sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://192.168.0.12:2403/"]];

		notes = [NSMutableArray array];
		notesDict = [NSMutableDictionary dictionary];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

		[NSTimer scheduledTimerWithTimeInterval:NOTES_FLUSH_TO_SERVER_INTERVAL target:self selector:@selector(flushTimerFired:) userInfo:nil repeats:YES];

		[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadingNotification object:nil];

		[sessionManager GET:@"notes" parameters:nil success:^(NSURLSessionDataTask* task, id responseObject) {
			for (NSDictionary* record in responseObject) {
				Note* note = [[Note alloc] init];
				note.text = record[@"note"];
				note.recordID = record[@"id"];
				note.name = record[@"name"];
				note.dirty = NO;
				[notes addObject:note];
				notesDict[note.name] = note;
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadSucceededNotification object:nil];
		} failure:^(NSURLSessionDataTask* task, NSError* error) {
			[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadFailedNotification object:error];
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
			if (note.recordID == nil) {
				NSDictionary* parameters = @{ @"note": note.text, @"name": note.name };
				[sessionManager POST:@"notes" parameters:parameters success:^(NSURLSessionDataTask* task, id responseObject) {
					note.recordID = responseObject[@"id"];
					note.dirty = NO;
				} failure:^(NSURLSessionDataTask* task, NSError* error) {
				}];
			} else {
				NSDictionary* parameters = @{ @"note": note.text, @"name": note.name };
				[sessionManager PUT:[NSString stringWithFormat:@"notes/%@", note.recordID] parameters:parameters success:^(NSURLSessionDataTask* task, id responseObject) {
					note.dirty = NO;
				} failure:^(NSURLSessionDataTask* task, NSError* error) {
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
	[sessionManager DELETE:[NSString stringWithFormat:@"notes/%@", note.recordID] parameters:nil success:^(NSURLSessionDataTask* task, id responseObject) {
		performBlock(^() {
			[[NSNotificationCenter defaultCenter] postNotificationName:NoteDeletedNotification object:note];
		});
	} failure:^(NSURLSessionDataTask* task, NSError* error) {
	}];
}

- (void) handlePushToken:(NSData*)token
{
	const unsigned *tokenBytes = [token bytes];
	NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
						  ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
						  ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
						  ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
	NSLog(@"PUSH TOKEN: %@", hexToken);
	NSString* urlString = [NSString stringWithFormat:@"devices?apnToken=%@", hexToken];
	[sessionManager GET:urlString parameters:nil success:^(NSURLSessionDataTask* task, NSArray* responseObject) {
		if (responseObject.count == 0) {
			[self registerPushToken:hexToken];
		}
	} failure:^(NSURLSessionDataTask* task, NSError* error) {
		[self registerPushToken:hexToken];
	}];
}

- (void) registerPushToken:(NSString*)hexToken
{
	[sessionManager POST:@"devices" parameters:@{@"apnToken":hexToken} success:^(NSURLSessionDataTask* task, NSArray* responseObject) {
		NSLog(@"Successfully registered push token");
	} failure:^(NSURLSessionDataTask* task, NSError* error) {
		NSLog(@"Failed to register push token: %@", error);
	}];
}

- (void) handlePushNotification:(NSDictionary*)info
{
	NSLog(@"got notif %@",info);
	if (info[@"n"] != nil) {
		NSString* recordID = info[@"n"][@"id"];
		NSString* type = info[@"n"][@"t"];
		if ([type isEqualToString:@"add"] || [type isEqualToString:@"upd"]) {
			[sessionManager GET:[NSString stringWithFormat:@"notes/%@", recordID] parameters:nil success:^(NSURLSessionDataTask* task, id responseObject) {
				NSDictionary* dict = responseObject;
				if (notesDict[dict[@"name"]] != nil) {
					Note* note = notesDict[dict[@"name"]];
					note.text = dict[@"note"];
					note.recordID = recordID;
					note.dirty = NO;
					performBlock(^() {
						[[NSNotificationCenter defaultCenter] postNotificationName:NoteUpdatedNotification object:note];
					});
				} else {
					Note* note = [[Note alloc] init];
					note.text = dict[@"note"];
					note.recordID = recordID;
					note.name = dict[@"name"];
					note.dirty = NO;
					[notes addObject:note];
					notesDict[note.name] = note;
					performBlock(^() {
						[[NSNotificationCenter defaultCenter] postNotificationName:NoteCreatedNotification object:nil];
					});
				}
			} failure:^(NSURLSessionDataTask* task, NSError* error) {
			}];
		} else if ([type isEqualToString:@"del"]) {
			for (Note* note in notes) {
				if ([note.recordID isEqualToString:recordID]) {
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
