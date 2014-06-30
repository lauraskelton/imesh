//
//  SSFindMessageManager.m
//  SimpleShare
//
//  Created by Laura Skelton on 1/11/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import "SSFindMessageManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "SimpleShare.h"

@interface SSFindMessageManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager      *centralManager;
@property (strong, nonatomic) CBPeripheral          *discoveredPeripheral;
//@property (strong, nonatomic) NSMutableData         *data;
@property (nonatomic, retain) NSMutableDictionary          *peripheralDataDict;
@property (nonatomic, retain) NSMutableArray        *allPeripherals;
@property (nonatomic, retain) NSMutableArray        *peripheralIDs;

-(void)addNewPeripheral:(CBPeripheral *)peripheral;
- (void)cleanupPeripheral:(CBPeripheral *)peripheral;
- (void)updateScan;

@end

@implementation SSFindMessageManager
@synthesize delegate, isAdvertising = _isAdvertising;

- (id)init {
	if ((self = [super init])) {
        
        // Start up the CBCentralManager
        dispatch_queue_t centralQueue = dispatch_queue_create("com.simpleshare.mycentral", DISPATCH_QUEUE_SERIAL);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralQueue options:@{ CBCentralManagerOptionRestoreIdentifierKey: @"82ebf110-0072-11e4-9191-0800200c9a66" }];
        
        // And somewhere to store the incoming data
        //_data = [[NSMutableData alloc] init];
        
        self.peripheralDataDict = [[NSMutableDictionary alloc] init];
        
        _foundOneMessage = NO;
        
        self.allPeripherals = [[NSMutableArray alloc] init];
        self.peripheralIDs = [[NSMutableArray alloc] init];

	}
	return self;
}

-(void)findMessageManagerWillStop:(id)sender
{
    // Don't keep it going while we're not showing.
    NSLog(@"Scanning stopped");
#warning clean up connections here?
    [self.centralManager stopScan];
    
}

-(void)setIsAdvertising:(BOOL)newIsAdvertising
{
    if (_isAdvertising != newIsAdvertising) {
        _isAdvertising = newIsAdvertising;
        
        [self updateScan];
    }
}

#pragma mark - Central Background Restoration Delegate

- (void)centralManager:(CBCentralManager *)central
      willRestoreState:(NSDictionary *)state {
    
    
    NSArray *peripherals =
    state[CBCentralManagerRestoredStatePeripheralsKey];
    
    NSLog(@"peripherals: %@", peripherals);
    
    for (CBPeripheral *peripheral in peripherals) {
        
        [self addNewPeripheral:peripheral];
    }
    
}

-(void)addNewPeripheral:(CBPeripheral *)peripheral
{
    if (![self.peripheralIDs containsObject:peripheral.identifier]) {
        
        // retain this peripheral
        [self.allPeripherals addObject:peripheral];
        
        // redundant if we are retaining the peripheral in array allPeripherals?
        self.discoveredPeripheral = peripheral;
        
        // Stop scanning
        [self.centralManager stopScan];
        NSLog(@"Scanning stopped");
        
        // And connect
        NSLog(@"Connecting to peripheral %@", peripheral);
        [self.peripheralIDs addObject:peripheral.identifier];
        
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

#pragma mark - Central Methods

// Use CBCentralManager to check whether the current platform/hardware supports Bluetooth LE.
- (BOOL)isLECapableHardware
{

    NSString * state = nil;
    switch ([self.centralManager state]) {
        case CBCentralManagerStateUnsupported:
            state = @"Your hardware doesn't support Bluetooth LE sharing.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"This app is not authorized to use Bluetooth. You can change this in the Settings app.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStateResetting:
            state = @"Bluetooth is currently resetting.";
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@"powered on");
            return TRUE;
        case CBCentralManagerStateUnknown:
            NSLog(@"state unknown");
            return FALSE;
        default:
            return FALSE;
            
    }
    NSLog(@"Central manager state: %@", state);
    [self endFindMessage:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate findMessageManagerDidFailWithMessage:state];
    });
    
    return FALSE;
}

/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self updateScan];
}


/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)updateScan
{
    
    if ([self isLECapableHardware] != YES) {
        NSLog(@"not capable");
        return;
    }
    
    NSLog(@"capable");
    
    if (!_isAdvertising) {

        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:[SimpleShare sharedInstance].simpleShareAppID]]
                                                    options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        
        
        NSLog(@"Scanning started");
    } else {
        [self.centralManager stopScan];
        
        // reset data to avoid half-sent messages
        for (id key in self.peripheralDataDict) {
            NSMutableData *data = [[NSMutableData alloc] init];
            [self.peripheralDataDict setObject:data forKey:key];
        }
    }
}


/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered %@ %@ at %@", peripheral.name, peripheral.identifier, RSSI);
        
    [self addNewPeripheral:peripheral];
    
}


/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    //[self cleanup];
    [self.peripheralIDs removeObject:peripheral.identifier];
    [self.allPeripherals removeObject:peripheral];
    [self.peripheralDataDict removeObjectForKey:peripheral.identifier];
}


/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");
    
    // Clear the data that we may already have
    NSMutableData *data = [[NSMutableData alloc] init];
    
    [self.peripheralDataDict setObject:data forKey:peripheral.identifier];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:[SimpleShare sharedInstance].simpleShareAppID]]];
}


/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanupPeripheral:peripheral];
        return;
    }
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:[SimpleShare sharedInstance].simpleShareAppID]] forService:service];
    }
}


/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanupPeripheral:peripheral];
        return;
    }
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[SimpleShare sharedInstance].simpleShareAppID]]) {
            
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}


/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error updating characteristics: %@", [error localizedDescription]);
        return;
    }
    
    // handle only one message at a time
    if (!_isAdvertising) {
        NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        
        // Have we got everything we need?
        if ([stringFromData isEqualToString:@"EOM"]) {
            
            // We have, so show the data,
            NSLog(@"complete received message: %@", [[NSString alloc] initWithData:[self.peripheralDataDict objectForKey:peripheral.identifier] encoding:NSUTF8StringEncoding]);
            //[self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
            
            NSString *messageString = [[NSString alloc] initWithData:[self.peripheralDataDict objectForKey:peripheral.identifier] encoding:NSUTF8StringEncoding];
            
            if ([messageString length] > 0) {
                [self addMessage:messageString];
            }
            
            // reset data but keep connected
            NSMutableData *data = [[NSMutableData alloc] init];
            [self.peripheralDataDict setObject:data forKey:peripheral.identifier];
        }
        
        // Otherwise, just add the data on to what we already have
        [[self.peripheralDataDict objectForKey:peripheral.identifier] appendData:characteristic.value];
        
        // Log it
        NSLog(@"Received: %@", stringFromData);
    }
    
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:[SimpleShare sharedInstance].simpleShareAppID]]) {
        return;
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    }
    
    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}


/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
    
    [self.peripheralIDs removeObject:peripheral.identifier];
    
    [self.peripheralDataDict removeObjectForKey:peripheral.identifier];
    
    // We're disconnected, so start scanning again
    //[self updateScan];
}


/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanupPeripheral:(CBPeripheral *)peripheral
{
    
    // Don't do anything if we're not connected
    if (!peripheral.isConnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (peripheral.services != nil) {
        for (CBService *service in peripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[SimpleShare sharedInstance].simpleShareAppID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [peripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:peripheral];
    [self.peripheralIDs removeObject:peripheral.identifier];
    [self.peripheralDataDict removeObjectForKey:peripheral.identifier];
    [self.allPeripherals removeObject:peripheral];
}

#pragma mark - custom methods

-(void)addMessage:(NSString *)messageToAdd
{
    NSLog(@"found message: %@", messageToAdd);
        
        // tell the delegate
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate findMessageManagerFoundMessage:messageToAdd];
        });
    
}

-(void)endFindMessage:(id)sender
{
    [self findMessageManagerWillStop:nil];
}

#pragma mark - Dealloc

- (void)dealloc {
    [self.centralManager stopScan];
    
    for (CBPeripheral *peripheral in self.allPeripherals) {
        [self cleanupPeripheral:peripheral];
    }
    
    self.discoveredPeripheral = nil;
    
    self.centralManager.delegate = nil;
    self.centralManager = nil;
    
}

@end
