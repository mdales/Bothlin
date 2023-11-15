//
//  KeyCollectionView.m
//  Bothlin
//
//  Created by Michael Dales on 13/11/2023.
//

#import "KeyCollectionView.h"

@implementation KeyCollectionView

- (void)keyDown:(NSEvent *)event {
    id<KeyCollectionViewDelegate> keyDelegate = self.keyDelegate;
    if (nil == keyDelegate) {
        [super keyDown:event];
        return;
    }

    if (NSKeyDown == event.type) {
        switch (event.keyCode) {
            case 49: { // space
                    BOOL success = [keyDelegate keyCollectionView:self
                                            presentItemsAtIndexes:self.selectionIndexes];
                    if (NO != success) {
                        return;
                    }
                }
                break;
            default:
                break;
        }
    }
    [super keyDown:event];
}

@end
