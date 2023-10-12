//
//  SidebarItem.m
//  Bothlin
//
//  Created by Michael Dales on 12/10/2023.
//

#import "SidebarItem.h"

@implementation SidebarItem

- (instancetype)initWithTitle:(NSString *)title
                   symbolName:(NSString *)symbolName
                     children:(NSArray<SidebarItem *> *)children {
    NSAssert(nil != title, @"Sidebar item must have non nil title");
    self = [super init];
    if (nil != self) {
        self->_title = title;
        if (nil != symbolName) {
            self->_icon = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
        }
        self->_children = children;
    }
    return self;
}

@end
