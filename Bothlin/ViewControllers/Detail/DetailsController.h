//
//  DetailsController.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

#import "TagViewItem.h"

@class Asset;
@class Tag;

@class DetailsController;

NS_ASSUME_NONNULL_BEGIN

@protocol DetailsControllerDelegate <NSObject>

- (void)addTagViaDetailsController:(DetailsController *)detailsController;
- (void)detailsViewController:(DetailsController *)detailsController
                    removeTag:(Tag *)tag
                    fromAsset:(Asset *)asset;

@end

@interface DetailsController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate, NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout, TagViewItemDelegate>

// Only access from mainQ
@property (nonatomic, weak, readwrite) IBOutlet NSOutlineView *detailsView;
@property (nonatomic, weak, readwrite) IBOutlet NSTextField *notesView;
@property (nonatomic, weak, readwrite) IBOutlet NSButton *addTagButton;
@property (nonatomic, weak, readwrite) IBOutlet NSCollectionView *tagCollectionView;
@property (nonatomic, weak, readwrite, nullable) id<DetailsControllerDelegate> delegate;

- (void)setItemForDisplay:(Asset * _Nullable)item;

- (IBAction)textFieldUpdated:(id)sender;
- (IBAction)addTag:(id)sender;

@end

NS_ASSUME_NONNULL_END
