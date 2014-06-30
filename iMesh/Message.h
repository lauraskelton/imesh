//
//  Message.h
//  iMesh
//
//  Created by Laura Skelton on 6/27/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Message : NSManagedObject

@property (nonatomic, retain) NSString * messageString;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSNumber * hops;
@property (nonatomic, retain) NSNumber * fromUser;
@property (nonatomic, retain) NSNumber * toUser;
@property (nonatomic, retain) NSNumber * messageID;

+(Message *) insertMessageFromDictionary:(NSDictionary *)messageDictionary inManagedObjectContext:(NSManagedObjectContext *)context;

+(NSDictionary *)dictionaryFromMessage:(Message *)message;
+(NSDictionary *)dictionaryForNewMessage:(NSString *)messageString;

@end
