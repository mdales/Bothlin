//
//  SettingsWindowController.h
//  Bothlin
//
//  Created by Michael Dales on 08/10/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsWindowController : NSWindowController

@property (nonatomic, weak, readwrite) IBOutlet NSButton *defaultStorageLocationRadio;
@property (nonatomic, weak, readwrite) IBOutlet NSButton *customStorageLocationRadio;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *customStorageLocationLabel;

- (IBAction)storageLocationChanged:(id)sender;

@end

NS_ASSUME_NONNULL_END
