//
//  SidebarItem.m
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 12/10/2023.
//

#import "SidebarItem.h"

@implementation SidebarItem

- (instancetype)initWithTitle:(NSString *)title
                   symbolName:(NSString * _Nullable)symbolName
                     children:(NSArray<SidebarItem *> * _Nullable)children
                 fetchRequest:(NSFetchRequest * _Nullable)fetchRequest {
    NSAssert(nil != title, @"Sidebar item must have non nil title");
    self = [super init];
    if (nil != self) {
        self->_title = [NSString stringWithString:title];
        if (nil != symbolName) {
            self->_icon = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
        }
        self->_fetchRequest = [fetchRequest copy];
        self->_children = nil != children ? [NSArray arrayWithArray:children] : nil;
    }
    return self;
}

@end
