//
//  AssetPromiseProvider.m
//  Bothlin
//
//  Created by Michael Dales on 29/10/2023.
//

#import "AssetPromiseProvider.h"


NSPasteboardType __nonnull const kAssetProviderType = @"com.digitalflapjack.bam-asset";

NSString * __nonnull const kAssetPromiseProviderURLKey = @"url";
NSString * __nonnull const kAssetPromiseProviderIndexPathKey = @"indexPath";

@implementation AssetPromiseProvider

- (NSArray<NSPasteboardType> *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    NSArray<NSPasteboardType> *defaults = [super writableTypesForPasteboard: pasteboard];
    NSArray<NSPasteboardType> *additions = @[
        NSPasteboardTypeFileURL,
        kAssetProviderType,
    ];
    return [defaults arrayByAddingObjectsFromArray:additions];
}

- (id)pasteboardPropertyListForType:(NSPasteboardType)type {
    NSAssert([self.userInfo isKindOfClass:[NSDictionary class]], @"User info should be dict");
    NSDictionary *userInfo = (NSDictionary *)self.userInfo;

    if ([type compare:NSPasteboardTypeFileURL] == NSOrderedSame) {
        id maybeURL = userInfo[kAssetPromiseProviderURLKey];
        if ((nil != maybeURL) && ([maybeURL isKindOfClass:[NSURL class]])) {
            NSURL *url = (NSURL *)maybeURL;
            return [url pasteboardPropertyListForType:type];
        }
    } else if ([type compare:kAssetProviderType] == NSOrderedSame) {
        NSData *data = userInfo[kAssetPromiseProviderIndexPathKey];
        return data;
    }

    return [super pasteboardPropertyListForType:type];
}

@end
