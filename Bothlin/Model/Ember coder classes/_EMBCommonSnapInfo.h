//
//  _EMBCommonSnapInfo.h
//  Bothlin
//
//  Created by Michael Dales on 04/12/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


// Names from looking at archives:
// systemVersion
// snapDate
// systemType
// emberBuildNumber

@interface _EMBCommonSnapInfo : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, strong, readonly) id emberBuildNumber; // Can be NSString or NSNumber
@property (nonatomic, strong, readonly) NSNumber *systemVersion;
@property (nonatomic, strong, readonly) NSDate *snapDate;
@property (nonatomic, strong, readonly) NSString *systemType;

@end

NS_ASSUME_NONNULL_END
