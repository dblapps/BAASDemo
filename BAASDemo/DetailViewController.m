//
//  DetailViewController.m
//  BAASDemo
//
//  Created by David Levi on 1/31/16.
//  Copyright © 2016 Double Apps. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController () <UITextViewDelegate>
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (void) setNote:(Note*)note
{
	if (_note != note) {
		_note = note;
	        
	    // Update the view.
	    [self configureView];
		[self.textView becomeFirstResponder];
	}
}

- (void)configureView {
	// Update the user interface for the detail item.
	if (self.note) {
	    self.textView.text = self.note.text;
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	[self configureView];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteUpdated:) name:NoteUpdatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteDeleted:) name:NoteDeletedNotification object:nil];
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (self.note != nil) {
		[self.textView becomeFirstResponder];
	}
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void) noteUpdated:(NSNotification*)notification
{
	if (notification.object == self.note) {
		self.textView.text = self.note.text;
	}
}

- (void) noteDeleted:(NSNotification*)notification
{
	if (notification.object == self.note) {
		self.textView.text = @"";
		if (self.splitViewController.collapsed) {
			[(UINavigationController *)self.splitViewController.viewControllers[0] popToRootViewControllerAnimated:YES];
		}
	}
}


#pragma mark - UITextViewDelegate

//- (void) textViewDidChange:(UITextView *)textView
//{
//	self.note.text = textView.text;
//	[self.delegate noteTextChanged:self.note];
//}

- (BOOL) textViewShouldBeginEditing:(UITextView *)textView
{
	return (self.note != nil);
}

- (BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
	self.note.text = [textView.text stringByReplacingCharactersInRange:range withString:text];
	[self.delegate noteTextChanged:self.note];
	return YES;
}

@end
