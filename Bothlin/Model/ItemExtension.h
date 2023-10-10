//
//  ItemExtension.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "Item+CoreDataClass.h"

@interface Item (Helpers)

+ (NSSet<Item *> * _Nullable)importItemsAtURL:(NSURL * _Nonnull)url
                          inContext:(NSManagedObjectContext * _Nonnull)context
                              error:(NSError * _Nullable * _Nullable)error ;

- (NSURL* _Nullable)decodeSecureURL:(NSError * _Nullable * _Nullable)error;
@end
