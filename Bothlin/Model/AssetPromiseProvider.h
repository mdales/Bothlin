//
//  AssetPromiseProvider.h
//  Bothlin
//
//  Created by Michael Dales on 29/10/2023.
//

#import <Cocoa/Cocoa.h>

extern NSPasteboardType __nonnull const kAssetProviderType;

extern NSString * __nonnull const kAssetPromiseProviderURLKey;
extern NSString * __nonnull const kAssetPromiseProviderIndexPathKey;

NS_ASSUME_NONNULL_BEGIN

@interface AssetPromiseProvider : NSFilePromiseProvider

@end

NS_ASSUME_NONNULL_END
