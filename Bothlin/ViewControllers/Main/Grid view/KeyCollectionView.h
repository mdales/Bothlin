//
//  KeyCollectionView.h
//  Bothlin
//
//  Created by Michael Dales on 13/11/2023.
//

#import <Cocoa/Cocoa.h>

@class KeyCollectionView;

NS_ASSUME_NONNULL_BEGIN

@protocol KeyCollectionViewDelegate <NSObject>

- (void)keyCollectionView:(KeyCollectionView *)keyCollectionView
    presentItemsAtIndexes:(NSIndexSet *)indexes;

@end

@interface KeyCollectionView : NSCollectionView

@property (nonatomic, weak, readwrite) id<KeyCollectionViewDelegate> keyDelegate;

@end

NS_ASSUME_NONNULL_END
