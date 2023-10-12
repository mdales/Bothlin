//
//  SidebarItem.h
//  Bothlin
//
//  Created by Michael Dales on 12/10/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SidebarItem : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly, nullable) NSImage *icon;
@property (nonatomic, strong, readonly, nullable) NSArray<SidebarItem *> *children;

- (instancetype)initWithTitle:(NSString *)title
                   symbolName:(NSString * _Nullable)symbolName
                     children:(NSArray<SidebarItem *> * _Nullable)children;

@end

NS_ASSUME_NONNULL_END
