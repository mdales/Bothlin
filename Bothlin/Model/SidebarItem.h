//
//  SidebarItem.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 12/10/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SidebarItemDragResponse) {
    SidebarItemDragResponseNone = 0,
    SidebarItemDragResponseFavourite = 1,
    SidebarItemDragResponseGroup = 2,
    SidebarItemDragResponseTrash = 3,
};

@interface SidebarItem : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly, nullable) NSImage *icon;
@property (nonatomic, strong, readonly, nullable) NSArray<SidebarItem *> *children;
@property (nonatomic, strong, readonly, nullable) NSFetchRequest *fetchRequest;
@property (nonatomic, readonly) SidebarItemDragResponse dragResponseType;
@property (nonatomic, strong, readonly, nullable) NSManagedObjectID *relatedOject;
@property (nonatomic, strong, readonly) NSUUID *uuid;

- (instancetype)initWithTitle:(NSString *)title
                   symbolName:(NSString * _Nullable)symbolName
             dragResponseType:(SidebarItemDragResponse)dragResponseType
                     children:(NSArray<SidebarItem *> * _Nullable)children
                 fetchRequest:(NSFetchRequest * _Nullable)fetchRequest
                relatedObject:(NSManagedObjectID * _Nullable)relatedObject
                         uuid:(NSUUID *)uuid;

@end

NS_ASSUME_NONNULL_END
