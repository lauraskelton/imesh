//
//  SSShareMessageManager.h
//  SimpleShare
//
//  Created by Laura Skelton on 1/11/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class AppDelegate;
@class SSShareItemManager;


@protocol SSShareMessageManagerDelegate <NSObject>
- (void)shareMessageManagerDidFailWithMessage:(NSString *)failMessage;
-(void)shareMessageManagerDidFinishSharing;
-(void)shareMessageManagerNotReady;
@end

@interface SSShareMessageManager : NSObject <CBPeripheralManagerDelegate>

@property (nonatomic, assign) id <SSShareMessageManagerDelegate> delegate;
@property (nonatomic, retain) NSString *messageString;
@property (nonatomic, assign) BOOL isReadyToAdvertise;

- (void)stopAdvertising:(id)sender;
- (void)startAdvertising:(id)sender;
-(BOOL)isPeripheralAdvertising:(id)sender;

-(void)shouldAdvertise:(id)sender;

@end
