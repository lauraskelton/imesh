//
//  MasterViewController.h
//  iMesh
//
//  Created by Laura Skelton on 6/26/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


@interface MasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
