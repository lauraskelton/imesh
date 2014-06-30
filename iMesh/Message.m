//
//  Message.m
//  iMesh
//
//  Created by Laura Skelton on 6/27/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import "Message.h"


@implementation Message

@dynamic messageString;
@dynamic timestamp;
@dynamic hops;
@dynamic fromUser;
@dynamic toUser;
@dynamic messageID;

+(Message *) insertMessageFromDictionary:(NSDictionary *)messageDictionary inManagedObjectContext:(NSManagedObjectContext *)context
{
    
    Message *message = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    request.entity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:@"messageID = %@",[messageDictionary objectForKey:@"messageID"]];
    NSError *executeFetchError= nil;
    message = [[context executeFetchRequest:request error:&executeFetchError] lastObject];
    
    if (executeFetchError) {
        NSLog(@"[%@, %@] error looking up message with id: %@ with error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [messageDictionary objectForKey:@"messageID"], [executeFetchError localizedDescription]);
    } else if(!message) {
        
        message = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
                                                       inManagedObjectContext:context];
        
        message.messageID = @([[messageDictionary objectForKey:@"messageID"] integerValue]);
        message.fromUser = @([[messageDictionary objectForKey:@"fromUser"] integerValue]);
        message.toUser = @([[messageDictionary objectForKey:@"toUser"] integerValue]);
        message.hops = @([[messageDictionary objectForKey:@"hops"] integerValue]);
        message.messageString = [messageDictionary objectForKey:@"messageString"];
        message.timestamp = [NSDate dateWithTimeIntervalSince1970:[[messageDictionary objectForKey:@"timestamp"] integerValue]];
        
    }
    
    return message;
}

+(NSDictionary *)dictionaryFromMessage:(Message *)message
{
    NSDictionary *messageDictionary = [[NSMutableDictionary alloc] init];
    [messageDictionary setValue:message.messageString forKey:@"messageString"];
    [messageDictionary setValue:@([message.timestamp timeIntervalSince1970]) forKey:@"timestamp"];
    [messageDictionary setValue:message.fromUser forKey:@"fromUser"];
    [messageDictionary setValue:message.toUser forKey:@"toUser"];
    [messageDictionary setValue:message.messageID forKey:@"messageID"];
    [messageDictionary setValue:message.hops forKey:@"hops"];
    
    return messageDictionary;
}

+(NSDictionary *)dictionaryForNewMessage:(NSString *)messageString
{
    NSDictionary *messageDictionary = [[NSMutableDictionary alloc] init];
    [messageDictionary setValue:messageString forKey:@"messageString"];
    [messageDictionary setValue:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
    [messageDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"iMeshUserIDKey"] forKey:@"fromUser"];
    [messageDictionary setValue:@(0) forKey:@"toUser"];
    int randomID = arc4random() % 900000 + 100000;
    [messageDictionary setValue:@(randomID) forKey:@"messageID"];
    [messageDictionary setValue:@(0) forKey:@"hops"];
    
    return messageDictionary;
}

@end
