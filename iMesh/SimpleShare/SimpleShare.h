//
//  SimpleShare.h
//  SimpleShare Demo
//
//  Created by Laura Skelton on 1/11/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SimpleShare;

@protocol SimpleShareDelegate <NSObject>
- (void)simpleShareFoundMessage:(NSDictionary *)messageDictionary;
- (void)simpleShareDidFailWithMessage:(NSString *)failMessage;
@end

@interface SimpleShare : NSObject <UIAlertViewDelegate>

@property (nonatomic, assign) id <SimpleShareDelegate> delegate;
@property (nonatomic, retain) NSString *simpleShareAppID;
@property (nonatomic, assign) BOOL isListening;

+ (SimpleShare *)sharedInstance;

-(void)shareMessage:(NSDictionary *)messageDictionary;

@end