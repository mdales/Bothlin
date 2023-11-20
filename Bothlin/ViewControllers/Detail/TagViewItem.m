//
//  TagViewItem.m
//  Bothlin
//
//  Created by Michael Dales on 19/11/2023.
//

#import "TagViewItem.h"
#import "Tag+CoreDataClass.h"

@interface TagViewItem ()

@end

@implementation TagViewItem

+ (NSSize)sizeForTagName:(NSString *)name {
    NSFont *font = [NSFont systemFontOfSize:12];
    NSSize textSize = [name sizeWithAttributes:@{NSFontAttributeName:font}];

    return NSMakeSize(textSize.width + 25.0 + 25.0, 25.0);
}

- (void)setTag:(Tag *)tag {
    dispatch_assert_queue(dispatch_get_main_queue());
    if (tag == self->_tag) {
        return;
    }
    self->_tag = tag;
    [self.textField setStringValue:tag.name];
}

- (IBAction)removeButtonClicked:(id)sender {
    [self.delegate tagViewItemWasRemoved:self];
}

@end
