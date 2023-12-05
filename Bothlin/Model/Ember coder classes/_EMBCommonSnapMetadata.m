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

        id possibleTags = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSString class], [NSMutableArray class]]] forKey:@"tags"];
        if (nil == possibleTags) {
            self->_tags = [NSSet set];
        } else {
            if ([possibleTags isKindOfClass:[NSString class]]) {
                self->_tags = [NSSet setWithObject:possibleTags];
            } else {
                self->_tags = [NSSet setWithArray:possibleTags];
            }
        }

        self->_collections = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSString class], [NSMutableArray class]]] forKey:@"collections"];

        NSValue *possibleIimageDimensions = [coder decodeObjectOfClass:[NSValue class]
                                                                forKey:@"imageDimensions"];
        if (nil != possibleIimageDimensions) {
            self->_imageDimensions = [possibleIimageDimensions sizeValue];
        }

        self->_comments = [coder decodeObjectOfClass:[NSString class] forKey:@"comments"];
        self->_rating = [coder decodeObjectOfClass:[NSNumber class] forKey:@"rating"];
        if (nil == self->_rating) {
            self->_rating = @0;
        }
        self->_type = [coder decodeObjectOfClass:[NSNumber class] forKey:@"type"];
        self->_uuid = [coder decodeObjectOfClass:[NSString class] forKey:@"uuid"];
        self->_date = [coder decodeObjectOfClass:[NSDate class] forKey:@"date"];


        self->_colourRedComponent = [coder decodeObjectOfClass:[NSNumber class] forKey:@"colourRedComponent"];
        self->_colourGreenComponent = [coder decodeObjectOfClass:[NSNumber class] forKey:@"colourGreenComponent"];
        self->_colourBlueComponent = [coder decodeObjectOfClass:[NSNumber class] forKey:@"colourBlueComponent"];

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
