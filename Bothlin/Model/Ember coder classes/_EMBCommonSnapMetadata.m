//
//  _EMBCommonSnapMetadata.m
//  Bothlin
//
//  Created by Michael Dales on 04/12/2023.
//

#import "_EMBCommonSnapMetadata.h"

@implementation _EMBCommonSnapMetadata

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *title = [coder decodeObjectOfClass:[NSString class]
                                          forKey:@"title"];
    if (nil == title) {
        return nil;
    }
    NSString *imageFileName = [coder decodeObjectOfClass:[NSString class]
                                                  forKey:@"imageFileName"];
    if (nil == imageFileName) {
        return nil;
    }

    self = [super init];
    if (nil != self) {
        self->_title = title;
        self->_imageFileName = imageFileName;

        self->_compositedImageFileName = [coder decodeObjectOfClass:[NSString class] forKey:@"compositedImageFileName"];
        self->_webArchiveFileName = [coder decodeObjectOfClass:[NSString class] forKey:@"webArchiveFileName"];

        self->_tags = [coder decodeObjectOfClass:[NSMutableArray class] forKey:@"tags"];

        self->_hasAnnoations = [coder decodeBoolForKey:@"hasAnnotations"];
        self->_layered = [coder decodeBoolForKey:@"layered"];
        self->_colorAnalysed = [coder decodeBoolForKey:@"colourAnalysed"];
        self->_hasWebArchive = [coder decodeBoolForKey:@"hasWebArchive"];

        // TODO: decode more of this!

    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end
