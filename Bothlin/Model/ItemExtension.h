//
//  ItemExtension.h
//  Bothlin
//
//  Created by Michael Dales on 28/09/2023.
//

#import "Item+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface Item (Helpers)

+ (BOOL)importItemsAtURL: (NSURL *)url
               inContext: (NSManagedObjectContext *)context
                   error: (NSError **)error ;

@end

NS_ASSUME_NONNULL_END
