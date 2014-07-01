//
//  SimpleShare.m
//  SimpleShare Demo
//
//  Created by Laura Skelton on 1/11/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import "SimpleShare.h"

#import "SSShareMessageManager.h"
#import "SSFindMessageManager.h"

#define kSSAskedBluetoothPermissionKey @"ss_askedbluetoothpermission_key"

#define kShareMessageForTime 10.0f

// listen for messages

// found a message: stop listening for new messages,
// share this message for X seconds (10?)

// after sharing message time is up, delete the message,
// turn off the sharing manager, and go back to
// finding messages (listening).

// Sharing messages must be in foreground mode.
// Finding messages could be in background mode.
// Need to work on recreating central and peripheral managers after returns to foreground.

// Start with foreground, broadcast-style.


// private methods
@interface SimpleShare () <SSShareMessageManagerDelegate, SSFindMessageManagerDelegate>

@property (nonatomic, retain) NSString *bluetoothPermissionExplanation;
@property (nonatomic, retain) SSShareMessageManager *shareManager;
@property (nonatomic, retain) SSFindMessageManager *findManager;
@property (nonatomic, retain) NSDictionary *messageDictionary;

-(void)startSharingMessage:(id)sender;
-(void)stopSharingMessage:(id)sender;
-(void)findNearbyMessages:(id)sender;
-(void)stopFindingNearbyMessages:(id)sender;
-(void)switchToSharingMode:(id)sender;
-(void)switchToListeningMode:(id)sender;
-(void)checkBluetoothPermissionsSharing:(BOOL)isSharing;

-(void)advertisingTimerCallback:(id)sender;
-(void)stopAdvertisingCallback:(id)sender;

@end

@implementation SimpleShare

@synthesize shareManager = _shareManager, findManager = _findManager, simpleShareAppID = _simpleShareAppID, messageDictionary = _messageDictionary, bluetoothPermissionExplanation, delegate, isListening = _isListening;

+ (SimpleShare *)sharedInstance
{
    static SimpleShare *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[SimpleShare alloc] init];
    });
    
    return _sharedInstance;
}

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    // default bluetooth permissions explanation - you can set this to a custom explanation
    // e.g. [SimpleShare sharedInstance].bluetoothPermissionExplanation = @"We use bluetooth to share your groups nearby.";
    
    self.bluetoothPermissionExplanation = @"This app uses Bluetooth to find and share messages nearby.";
    
    // start listening for messages
    [self startFindingNearbyMessages:nil];
    
    _shareManager = [[SSShareMessageManager alloc] init];
    _shareManager.delegate = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(advertisingTimerCallback:) withObject:nil afterDelay:30.0];
    });
    
    return self;
}

-(void)advertisingTimerCallback:(id)sender
{
    // we should start advertising now (for 30 seconds) and stop scanning
    if (_findManager != nil) {
        _findManager.isAdvertising = YES;
    }
    
    if (_shareManager == nil) {
        _shareManager = [[SSShareMessageManager alloc] init];
        _shareManager.delegate = self;
    }
    
    [_shareManager shouldAdvertise:nil];
    
    // stop sharing after X seconds
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(stopAdvertisingCallback:) withObject:nil afterDelay:30];
    });
}

-(void)stopAdvertisingCallback:(id)sender
{
    [_shareManager stopAdvertising:nil];
    
    if (_findManager != nil) {
        _findManager.isAdvertising = NO;
    }
    
    NSTimeInterval randomAdvertisingInterval = arc4random_uniform(240); // should advertise about once every 5 minutes (?)
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(advertisingTimerCallback:) withObject:nil afterDelay:randomAdvertisingInterval];
    });
}

-(void)dealloc
{
    _simpleShareAppID = nil;
    _shareManager = nil;
    _findManager = nil;
}

-(void)checkBluetoothPermissionsSharing:(BOOL)isSharing
{
    // we haven't asked bluetooth permission before, so show alertview asking for it
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kSSAskedBluetoothPermissionKey];
    
    NSString *titleString;
    NSInteger tag;
    
    if (isSharing == YES) {
        titleString = @"Share with Bluetooth";
        tag = 1;
    } else {
        titleString = @"Find with Bluetooth";
        tag = 2;
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:titleString message:self.bluetoothPermissionExplanation delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    alert.tag = tag;
    [alert show];
}

-(void)switchToSharingMode:(id)sender
{
    // don't listen and share at the same time- causes bluetooth errors
    //[self stopFindingNearbyMessages:nil];
    
    [self startSharingMessage:nil];
    
    // doing this with delegate method instead
    /*
    // stop sharing after X seconds
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(switchToListeningMode:) withObject:nil afterDelay:kShareMessageForTime];
    });
     */
}

-(void)switchToListeningMode:(id)sender
{
    //[self stopSharingMessage:nil];
    
    _shareManager.messageString = nil;
    
    // start listening after X seconds so we don't hear the same message again (later we'll check for duplicates)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(findNearbyMessages:) withObject:nil afterDelay:0.1];
    });
}

-(void)shareMessage:(NSDictionary *)messageDictionary
{
    self.messageDictionary = messageDictionary;
    
    // First check if we've asked permission for bluetooth before
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSSAskedBluetoothPermissionKey] != YES) {
        [self checkBluetoothPermissionsSharing:YES];
        return;
    } else {
        [self switchToSharingMode:nil];
    }
}

-(void)startSharingMessage:(id)sender
{
    NSLog(@"start sharing message");
    if (_shareManager == nil) {
        _shareManager = [[SSShareMessageManager alloc] init];
        _shareManager.delegate = self;
    }
    
    if ([NSJSONSerialization isValidJSONObject:self.messageDictionary]) {
        NSError *error;
        _shareManager.messageString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self.messageDictionary options:NSJSONWritingPrettyPrinted error:&error] encoding:NSUTF8StringEncoding];
    }
}

-(void)stopSharingMessage:(id)sender
{
    if (_shareManager != nil) {
        [_shareManager stopAdvertising:nil];
        _shareManager = nil;
    }
}

-(void)startFindingNearbyMessages:(id)sender
{
    //[self stopFindingNearbyMessages:nil];
        
    // First check if we've asked permission for bluetooth before
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kSSAskedBluetoothPermissionKey] != YES) {
        [self checkBluetoothPermissionsSharing:NO];
        return;
    } else {
        [self switchToListeningMode:nil];
    }
}

-(void)findNearbyMessages:(id)sender
{
    if (_findManager == nil) {
        _findManager = [[SSFindMessageManager alloc] init];
        _findManager.delegate = self;
    }
    _findManager.isAdvertising = NO;
}

-(void)stopFindingNearbyMessages:(id)sender
{
    if (_findManager != nil) {
        [_findManager endFindMessage:nil];
        _findManager = nil;
    }
}

#pragma mark - Find Message Manager Delegate

- (void)findMessageManagerFoundMessage:(NSString *)messageString
{
    // tell the find manager we're advertising so it stops scanning
    self.findManager.isAdvertising = YES;
    
    NSError *error;
    NSMutableDictionary *messageDictionary = [[NSJSONSerialization JSONObjectWithData:[messageString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error] mutableCopy];
    
    NSLog(@"message: %@", messageDictionary);
    
    if (!([[messageDictionary objectForKey:@"messageID"] integerValue] == [[self.messageDictionary objectForKey:@"messageID"] integerValue])) {
        // tell the delegate to update the user interface with the found message
        [delegate simpleShareFoundMessage:messageDictionary];
        
        // notify user of new message
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = [NSString stringWithFormat:@"Message: %@ Hops: %@ From: %@", [messageDictionary objectForKey:@"messageString"], [messageDictionary objectForKey:@"hops"], [messageDictionary objectForKey:@"fromUser"]];
        notification.soundName = @"Default";
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        
        // update the number of hops +1
        [messageDictionary setObject:@([[messageDictionary objectForKey:@"hops"] integerValue] + 1) forKey:@"hops"];
        
        // then share this message for X seconds to relay it
        self.messageDictionary = messageDictionary;
        
        [self switchToSharingMode:nil];
    }
}

- (void)findMessageManagerDidFailWithMessage:(NSString *)failMessage
{
    // No bluetooth connection
    
    _findManager = nil;
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Bluetooth Support", nil) message:failMessage delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"OK", nil), nil] show];
    
    [delegate simpleShareDidFailWithMessage:failMessage];
}

#pragma mark - Share Message Manager Delegate

- (void)shareMessageManagerDidFailWithMessage:(NSString *)failMessage
{
    // No bluetooth connection
    
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Bluetooth Support", nil) message:failMessage delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"OK", nil), nil] show];
    
    [delegate simpleShareDidFailWithMessage:failMessage];
}

-(void)shareMessageManagerDidFinishSharing
{
    NSLog(@"share manager did finish sharing");
    [self switchToListeningMode:nil];
}

-(void)shareMessageManagerNotReady
{
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Not Ready", nil) message:@"Not quite ready to send messages." delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"OK", nil), nil] show];
    
    NSLog(@"NO CONNECTED CENTRALS");
    NSLog(@"Cannot share message.");
}

#pragma mark - Alert View Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 1) {
        // share messages bluetooth permission alert- start sharing messages
        [self startSharingMessage:nil];
    }
    else if (alertView.tag == 2) {
        // find messages bluetooth permission alert- start finding messages
        [self findNearbyMessages:nil];
    }
}

@end
