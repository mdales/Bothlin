//
//  TagViewItem.h
//  Bothlin
//
//  Created by Michael Dales on 19/11/2023.
//

#import <Cocoa/Cocoa.h>

@class Tag;
@class TagViewItem;

NS_ASSUME_NONNULL_BEGIN

@protocol TagViewItemDelegate <NSObject>

- (void)tagViewItemWasRemoved:(TagViewItem *)tagViewItem;

@end

@interface TagViewItem : NSCollectionViewItem

// Access only on mainQ
@property (nonatomic, weak, readwrite) id<TagViewItemDelegate> delegate;
@property (nonatomic, strong, readwrite) Tag *tag;

+ (NSSize)sizeForTagName:(NSString *)name;

- (IBAction)removeButtonClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END
