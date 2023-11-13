//
//  RootWindowController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "AssetsDisplayController.h"
#import "SidebarController.h"
#import "LibraryViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface RootWindowController : NSWindowController <NSToolbarDelegate, AssetsDisplayControllerDelegate, NSTextFieldDelegate, SidebarControllerDelegate, LibraryViewModelDelegate, NSSearchFieldDelegate>

// Group creation panel and controls.
@property (nonatomic, weak, readwrite) IBOutlet NSPanel *groupCreatePanel;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *groupCreateDuplicateWarningLabel;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *groupCreateNameField;
@property (nonatomic, weak, readwrite) IBOutlet NSButton *groupCreateOKButton;

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName __attribute__((unavailable("Use more specific constructor")));
- (instancetype)initWithWindowNibName:(NSNibName)windowNibName
                          viewContext:(NSManagedObjectContext *)viewContext
                     trashDisplayName:(NSString *)trashDisplayName;

// Menu and toolbar actions
- (IBAction)import:(id)sender;
- (IBAction)showGroupCreatePanel:(id)sender;
- (IBAction)debugRegenerateThumbnail:(id)sender;
- (IBAction)debugRegenerateScannedText:(id)sender;

// Group creation panel actions
- (IBAction)groupCreateOK:(id)sender;
- (IBAction)groupCreateCancel:(id)sender;
- (IBAction)groupNameFieldEnter:(id)sender;

@end

NS_ASSUME_NONNULL_END
