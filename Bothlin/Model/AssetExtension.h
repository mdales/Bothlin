//
//  AssetExtension.h
//  Bothlin - Copyright 2023 Digital Flapjack Ltd
//
//  Created by Michael Dales on 28/09/2023.
//

#import "Asset+CoreDataClass.h"

@interface Asset (Helpers)

- (NSURL* _Nullable)decodeSecureURL:(NSError * _Nullable * _Nullable)error;

@end
