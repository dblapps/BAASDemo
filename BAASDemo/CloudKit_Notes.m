//
//  Notes.m
//  BAASDemo
//
//  Created by David Levi on 1/31/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

#import "Notes.h"
#import <UIKit/UIKit.h>
#import <CloudKit/CloudKit.h>

static NSString* kSubscribed = @"com.dblapps.BAASDemo.Subscribed";

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
@property (strong,nonatomic) CKRecord* record;
@property (assign,nonatomic) BOOL dirty;
@end

@implementation Note

- (instancetype) init
{
	self = [super init];
	if (self != nil) {
		_text = @"";
		_record = nil;
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
		[[NSUserDefaults standardUserDefaults] registerDefaults:@{kSubscribed:@(NO)}];
		s_sharedNotes = [[Notes alloc] init];
	});

	return s_sharedNotes;
}

- (instancetype) init
{
	self = [super init];
	if (self != nil) {
		notes = [NSMutableArray array];
		notesDict = [NSMutableDictionary dictionary];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

		[NSTimer scheduledTimerWithTimeInterval:NOTES_FLUSH_TO_SERVER_INTERVAL target:self selector:@selector(flushTimerFired:) userInfo:nil repeats:YES];

		if (![[NSUserDefaults standardUserDefaults] boolForKey:kSubscribed]) {
			CKContainer* container = [CKContainer defaultContainer];
			CKDatabase* database = [container privateCloudDatabase];

			// Subscribe to changes in Notes table
			CKSubscription* subscription = [[CKSubscription alloc] initWithRecordType:@"Notes"
																			predicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]
																			  options:CKSubscriptionOptionsFiresOnRecordCreation|CKSubscriptionOptionsFiresOnRecordDeletion|CKSubscriptionOptionsFiresOnRecordUpdate];
			[database saveSubscription:subscription completionHandler:^(CKSubscription* subscription, NSError* error) {
				if (error != nil) {
					if (![error.domain isEqualToString:CKErrorDomain]) {
						return;
					}
					if (error.code != CKErrorServerRejectedRequest) {
						return;
					}
				}
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSubscribed];
				[self retrieveNotes];
			}];
		} else {
			[self retrieveNotes];
		}
	}
	return self;
}

- (void) retrieveNotes
{
	[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadingNotification object:nil];
	CKContainer* container = [CKContainer defaultContainer];
	CKDatabase* database = [container privateCloudDatabase];
	CKQuery* query = [[CKQuery alloc] initWithRecordType:@"Notes" predicate:[NSPredicate predicateWithFormat:@"TRUEPREDICATE"]];
	query.sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc]initWithKey:@"creationDate" ascending:true]];
	[database performQuery:query inZoneWithID:nil completionHandler:^(NSArray<CKRecord*>* results, NSError* error) {
		if (error == nil) {
			for (CKRecord* record in results) {
				Note* note = [[Note alloc] init];
				note.text = [record objectForKey:@"Note"];
				note.record = record;
				note.dirty = NO;
				[notes addObject:note];
				notesDict[record.recordID.recordName] = note;
			}
			performBlock(^() {
				[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadSucceededNotification object:nil];
			});
		} else {
			performBlock(^() {
				[[NSNotificationCenter defaultCenter] postNotificationName:NotesLoadFailedNotification object:error];
			});
		}
	}];
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
			if (note.record == nil) {
				CKRecordID* recordID = [[CKRecordID alloc] initWithRecordName:[NSUUID UUID].UUIDString];
				CKRecord* record = [[CKRecord alloc] initWithRecordType:@"Notes" recordID:recordID];
				[record setObject:note.text forKey:@"Note"];
				note.record = record;
			}
			CKContainer* container = [CKContainer defaultContainer];
			CKDatabase* database = [container privateCloudDatabase];
			[note.record setObject:note.text forKey:@"Note"];
			[database saveRecord:note.record completionHandler:^(CKRecord* record, NSError* error) {
				if (error == nil) {
					if ([note.text isEqualToString:[record objectForKey:@"Note"]]) {
						note.dirty = NO;
					}
				} else {
					NSLog(@"Error saving record: %@", error);
				}
			}];
		}
	}
}

- (Note*) newNote
{
	Note* note = [[Note alloc] init];
	CKRecordID* recordID = [[CKRecordID alloc] initWithRecordName:[NSUUID UUID].UUIDString];
	CKRecord* record = [[CKRecord alloc] initWithRecordType:@"Notes" recordID:recordID];
	[record setObject:note.text forKey:@"Note"];
	note.record = record;
	[notes addObject:note];
	notesDict[recordID.recordName] = note;
	performBlock(^() {
		[[NSNotificationCenter defaultCenter] postNotificationName:NoteCreatedNotification object:nil];
	});
	return note;
}

- (void) deleteNoteAtIndex:(NSInteger)index
{
	Note* note = notes[index];
	[notes removeObject:note];
	[notesDict removeObjectForKey:note.record.recordID.recordName];
	CKContainer* container = [CKContainer defaultContainer];
	CKDatabase* database = [container privateCloudDatabase];
	[database deleteRecordWithID:note.record.recordID completionHandler:^(CKRecordID* recordID, NSError* error) {
	}];
}

- (void) handlePushToken:(NSData*)token
{
	NSLog(@"PUSH TOKEN: %@", token);
}

- (void) handlePushNotification:(NSDictionary*)info
{
	NSLog(@"got notif %@",info);
	CKNotification *notification = [CKNotification notificationFromRemoteNotificationDictionary:info];
	if (notification.notificationType == CKNotificationTypeQuery) {
		CKQueryNotification* queryNotification = (CKQueryNotification*)notification;
		CKRecordID *recordId = queryNotification.recordID;
		if ((queryNotification.queryNotificationReason == CKQueryNotificationReasonRecordCreated) ||
			(queryNotification.queryNotificationReason == CKQueryNotificationReasonRecordUpdated)) {
			CKContainer* container = [CKContainer defaultContainer];
			CKDatabase* database = [container privateCloudDatabase];
			[database fetchRecordWithID:recordId completionHandler:^(CKRecord* record, NSError* error) {
				if ([record.recordType isEqualToString:@"Notes"]) {
					if (error == nil) {
						if (notesDict[recordId.recordName] != nil) {
							Note* note = notesDict[recordId.recordName];
							note.text = [record objectForKey:@"Note"];
							note.record = record;
							note.dirty = NO;
							performBlock(^() {
								[[NSNotificationCenter defaultCenter] postNotificationName:NoteUpdatedNotification object:note];
							});
						} else {
							Note* note = [[Note alloc] init];
							note.text = [record objectForKey:@"Note"];
							note.record = record;
							note.dirty = NO;
							[notes addObject:note];
							notesDict[record.recordID.recordName] = note;
							performBlock(^() {
								[[NSNotificationCenter defaultCenter] postNotificationName:NoteCreatedNotification object:nil];
							});
						}
					} else {
						NSLog(@"Error retrieving changed or created record: %@", error);
					}
				}
			}];
		} else {
			Note* note = notesDict[recordId.recordName];
			if (note != nil) {
				performBlock(^() {
					[notes removeObject:note];
					notesDict[recordId.recordName] = nil;
					[[NSNotificationCenter defaultCenter] postNotificationName:NoteDeletedNotification object:note];
				});
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
