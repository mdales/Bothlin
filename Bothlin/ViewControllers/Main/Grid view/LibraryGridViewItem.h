//
//  OSLibraryViewItem.h
//  Bothlin
//
//  Created by Michael Dales on 20/09/2023.
//

#import <Cocoa/Cocoa.h>

@class Item;

NS_ASSUME_NONNULL_BEGIN

@class LibraryGridViewItem;

@protocol LibraryGridViewItemDelegate <NSObject>

- (void)gridViewItemWasDoubleClicked:(LibraryGridViewItem *)gridViewItem;

@end

@interface LibraryGridViewItem : NSCollectionViewItem

@property (nonatomic, weak, readwrite) id<LibraryGridViewItemDelegate> delegate;

- (void)setItem:(Item *)item;

@end

NS_ASSUME_NONNULL_END
