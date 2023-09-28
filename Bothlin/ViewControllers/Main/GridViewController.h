//
//  GridViewController.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface GridViewController : NSViewController <NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (nonatomic, weak, readwrite) IBOutlet NSCollectionView *collectionView;

- (BOOL)reloadData: (NSError **)error;

@end

NS_ASSUME_NONNULL_END
