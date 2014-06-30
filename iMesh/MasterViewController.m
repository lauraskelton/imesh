//
//  MasterViewController.m
//  iMesh
//
//  Created by Laura Skelton on 6/26/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import "MasterViewController.h"

#import "SimpleShare.h"

#import "DetailViewController.h"
#import "Message.h"
#import "AppDelegate.h"

@interface MasterViewController () <SimpleShareDelegate, UITextFieldDelegate>

@property (nonatomic, retain) AppDelegate *appDelegate;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
-(NSString *)formatDate:(NSDate *)date;
-(void)shareMessage:(NSString *)messageToShare;
@end

@implementation MasterViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [SimpleShare sharedInstance].delegate = self;
    self.appDelegate = [UIApplication sharedApplication].delegate;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Simple Share Delegate

- (void)simpleShareFoundMessage:(NSDictionary *)messageDictionary
{
    NSLog(@"message found: %@", messageDictionary);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message" message:[messageDictionary objectForKey:@"messageString"] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [alert show];
    
    Message *thisMessage = [Message insertMessageFromDictionary:messageDictionary inManagedObjectContext:self.managedObjectContext];
    [self.appDelegate saveContext];
    thisMessage = nil;
}

- (void)simpleShareDidFailWithMessage:(NSString *)failMessage
{
    NSLog(@"simple share failed with error: %@", failMessage);
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 2;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][0];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                 cell = [tableView dequeueReusableCellWithIdentifier:@"UserIDCell" forIndexPath:indexPath];
                break;
            case 1:
                cell = [tableView dequeueReusableCellWithIdentifier:@"TextEntryCell" forIndexPath:indexPath];
                break;
            default:
                return nil;
                break;
        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"MessageCell" forIndexPath:indexPath];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        UITextField *textField;
        switch (indexPath.row) {
            case 0:
                textField = (UITextField *)[cell.contentView viewWithTag:3];
                textField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"iMeshUserIDKey"];
                break;
            case 1:
                textField = (UITextField *)[cell.contentView viewWithTag:2];
                break;
            default:
                break;
        }
        textField.delegate = self;
    } else {
        Message *aMessage = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:0]];
        cell.textLabel.text = aMessage.messageString;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"from: %@     hops: %@     at %@", aMessage.fromUser, aMessage.hops, [self formatDate:aMessage.timestamp]];
    }
}

-(NSString *)formatDate:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    NSLocale *locale = [NSLocale currentLocale];
    [formatter setLocale:locale];
    [formatter setDateFormat:@"h:mm a"];
    NSString *dateString = [formatter stringFromDate:date];
    formatter = nil;
    return dateString;
}

-(void)shareMessage:(NSString *)messageToShare
{
    NSDictionary *messageDictionary = [Message dictionaryForNewMessage:messageToShare];
    
    [[SimpleShare sharedInstance] shareMessage:messageDictionary];
}

#pragma mark - UITextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.tag == 2) {
        // message send textfield
        if ([textField.text length] > 0) {
            [self shareMessage:textField.text];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sharing Message" message:textField.text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
            
            textField.text = @"";
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Blank Message" message:@"Please enter a message to share." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        }
        
    }
    
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField.tag == 3) {
        [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"iMeshUserIDKey"];
        [textField resignFirstResponder];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _fetchedResultsController;
}

/*
 
 - (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
 {
 [self.tableView beginUpdates];
 }
 
 - (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
 atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
 {
 switch(type) {
 case NSFetchedResultsChangeInsert:
 [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
 break;
 
 case NSFetchedResultsChangeDelete:
 [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
 break;
 }
 }
 
 - (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
 atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
 newIndexPath:(NSIndexPath *)newIndexPath
 {
 UITableView *tableView = self.tableView;
 
 switch(type) {
 case NSFetchedResultsChangeInsert:
 [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
 break;
 
 case NSFetchedResultsChangeDelete:
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 break;
 
 case NSFetchedResultsChangeUpdate:
 [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
 break;
 
 case NSFetchedResultsChangeMove:
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
 break;
 }
 }
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
 {
 [self.tableView endUpdates];
 }
 */

// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}

@end













