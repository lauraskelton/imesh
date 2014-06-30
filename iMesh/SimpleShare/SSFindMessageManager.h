//
//  SSFindMessageManager.h
//  SimpleShare
//
//  Created by Laura Skelton on 1/11/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SSFindMessageManager;


@protocol SSFindMessageManagerDelegate <NSObject>
- (void)findMessageManagerFoundMessage:(NSString *)messageString;
- (void)findMessageManagerDidFailWithMessage:(NSString *)failMessage;
@end

@interface SSFindMessageManager : NSObject
{
    NSMutableArray *_foundPeripherals;
    BOOL _foundOneMessage;
}

@property (nonatomic, assign) id <SSFindMessageManagerDelegate> delegate;

-(void)addMessage:(NSString *)messageToAdd;
-(void)endFindMessage:(id)sender;
-(void)findMessageManagerWillStop:(id)sender;

@end
