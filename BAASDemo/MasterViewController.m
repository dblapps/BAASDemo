//
//  MasterViewController.m
//  BAASDemo
//
//  Created by David Levi on 1/31/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "Notes.h"

@interface MasterViewController () <DetailViewControllerDelegate>
@end

@implementation MasterViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
	self.navigationItem.rightBarButtonItem = addButton;
	self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notesLoading:) name:NotesLoadingNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notesLoadSucceeded:) name:NotesLoadSucceededNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notesLoadFailed:) name:NotesLoadFailedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteUpdated:) name:NoteUpdatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteCreated:) name:NoteCreatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteDeleted:) name:NoteDeletedNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender
{
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	if (indexPath != nil) {
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
	[self performSegueWithIdentifier:@"showDetail" sender:nil];
}

- (void) notesLoading:(NSNotification*)notification
{
}

- (void) notesLoadSucceeded:(NSNotification*)notification
{
	[self.tableView reloadData];
}

- (void) notesLoadFailed:(NSNotification*)notification
{
}

- (void) noteUpdated:(NSNotification*)notification
{
	Note* note = notification.object;
	NSUInteger row = [[Notes sharedNotes] indexOfObject:note];
	NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) noteCreated:(NSNotification*)notification
{
	NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[Notes sharedNotes].count-1 inSection:0];
	[self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) noteDeleted:(NSNotification*)notification
{
	[self.tableView reloadData];
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([[segue identifier] isEqualToString:@"showDetail"]) {
	    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
		Note* note = (indexPath == nil) ? [[Notes sharedNotes] newNote] : [Notes sharedNotes][indexPath.row];
	    DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
		controller.note = note;
		controller.delegate = self;
	    controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
	    controller.navigationItem.leftItemsSupplementBackButton = YES;
	}
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [Notes sharedNotes].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	Note* note = [Notes sharedNotes][indexPath.row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
	cell.textLabel.text = note.text;
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	// Return NO if you do not want the specified item to be editable.
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[[Notes sharedNotes] deleteNoteAtIndex:indexPath.row];
	    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
	    // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
	}
}

- (void) noteTextChanged:(Note *)note
{
	NSInteger row = [[Notes sharedNotes] indexOfObject:note];
	if (row != NSNotFound) {
		NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:0];
		[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
	}
}

@end





//
//  MasterViewController.m
//  BAASDemo
//
//  Created by David Levi on 1/31/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//
/*
#import "MasterViewController.h"
#import "DetailViewController.h"
#import "Notes.h"

@interface MasterViewController ()

@property NSMutableArray *objects;
@end

@implementation MasterViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	self.navigationItem.leftBarButtonItem = self.editButtonItem;

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
	self.navigationItem.rightBarButtonItem = addButton;
	self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notesLoading:) name:NotesLoadingNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
	[super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender {
	if (!self.objects) {
		self.objects = [[NSMutableArray alloc] init];
	}
	[self.objects insertObject:[NSDate date] atIndex:0];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
	[self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void) noteLoading:(NSNotification*)notification
{
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([[segue identifier] isEqualToString:@"showDetail"]) {
		NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
		NSDate *object = self.objects[indexPath.row];
		DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
		[controller setDetailItem:object];
		controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
		controller.navigationItem.leftItemsSupplementBackButton = YES;
	}
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

	NSDate *object = self.objects[indexPath.row];
	cell.textLabel.text = [object description];
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	// Return NO if you do not want the specified item to be editable.
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[self.objects removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	} else if (editingStyle == UITableViewCellEditingStyleInsert) {
		// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
	}
}

@end
*/
