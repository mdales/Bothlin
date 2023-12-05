//
//  _EMBCommonSnapInfo.m
//  Bothlin
//
//  Created by Michael Dales on 04/12/2023.
//

#import "_EMBCommonSnapInfo.h"

@implementation _EMBCommonSnapInfo

+ (BOOL)supportsSecureCoding {
    return YES;
}


- (instancetype)initWithCoder:(NSCoder *)coder {
    NSDate *snapDate = [coder decodeObjectOfClass:[NSDate class]
                                           forKey:@"snapDate"];
    if (nil == snapDate) {
        return nil;
    }
    NSString *systemType = [coder decodeObjectOfClass:[NSString class]
                                               forKey:@"systemType"];
    if (nil == systemType) {
        return nil;
    }
    NSNumber *systemVersion = [coder decodeObjectOfClass:[NSNumber class]
                                                  forKey:@"systemVersion"];
    if (nil == systemVersion) {
        return nil;
    }
    id emberBuildNumber = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSString class], [NSNumber class]]]
                                                forKey:@"emberBuildNumber"];
    if (nil == emberBuildNumber) {
        return nil;
    }

    self = [super init];
    if (nil != self) {
        self->_snapDate = snapDate;
        self->_systemType = systemType;
        self->_systemVersion = systemVersion;
        self->_emberBuildNumber = emberBuildNumber;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}


@end
