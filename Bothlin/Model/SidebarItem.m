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
             dragResponseType:(SidebarItemDragResponse)dragResponseType
                     children:(NSArray<SidebarItem *> * _Nullable)children
                 fetchRequest:(NSFetchRequest * _Nullable)fetchRequest
                relatedObject:(NSManagedObjectID * _Nullable)relatedObject 
                         uuid:(NSUUID *)uuid {
    NSParameterAssert(nil != title);
    NSParameterAssert(nil != uuid);
    self = [super init];
    if (nil != self) {
        self->_title = [NSString stringWithString:title];
        if (nil != symbolName) {
            self->_icon = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
        }
        self->_fetchRequest = [fetchRequest copy];
        self->_children = nil != children ? [NSArray arrayWithArray:children] : nil;
        self->_dragResponseType = dragResponseType;
        self->_relatedOject = relatedObject;
        self->_uuid = uuid;
    }
    return self;
}

@end
