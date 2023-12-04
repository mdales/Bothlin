//
//  _EMBCommonSnapMetadata.h
//  Bothlin
//
//  Created by Michael Dales on 04/12/2023.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The metadata is a keyed archive of type EMBCommonSnapMetadata. Again, for now we just pull out the bits we need. The
// size of this one is variable, and so we have to do a bit of guess work:
// There is an array of $objects, which contains:
// 0: $null
// 1: NSDictionary of 4 bools with some facts:
//    hasAnnotations
//    layered
//    colorAnalysed
//    hasWebArchive
// ..: Some NSStrings, on which in some it's the user given name, and sometimes also (first) a UUID of sorts
// ..: NSNumber 0
//
// ..optional: NSNumber 1
// ..optional: NSDictionary empty
//
// ..optional: NSString - URL of site captured
// ..optional: NSDictionary (2)
//    $classname: NSURL
//    $classes: Array
//        NSURL
//        NSObject
//
// ..optional: NSDictionary
//     NS.time: NSNumber = timestamp?
// ..optional: NSDictionary (2)
//    $classname: NSDate
//    $classes: Array
//        NSDate
//        NSObject
//
// ..optional: NSString - tag
// ..: NSDictionary (2)
//    $classname: NSMutableArray
//    $classes: Array
//        NSMutableArray
//        NSArray
//        NSObject
//
// ..: NSDictionary (1)
//    NS.objects: Array (empty)
// ..: NSDictionary (2)
//    $classname: NSArray
//    $classes: Array
//        NSArray
//        NSObject
//
// ..: NSDictionary (1)
//    NS.special: NSNumber = 2
//
// ..: NSString - "{0, 0}"
// ..: NSDictionary (2)
//    $classname: NSValue
//    $classes: Array
//        NSValue
//        NSObject
//
// ..: 1 or more NSStrings of files in the snap
//
// ..: NSDictionary (2)
//    $classname: _EMBCommonSnapMetadata
//    $classes: Array
//        _EMBCommonSnapMetadata
//        NSObject

// Names from looking at archives:
// sortColourValue
// U title
// S url
// T tags
// hasAnnotations
// _colourGreenComponent
// T uuid
// _colourRedComponent
// _webArchiveFileName
// W layered
// ^ colourAnalysed
// T type
// _ imageDimensions
// T date
// ] hasWebArchive
// X comments
// [ collections
// _ colourBlueComponent
// _ compositedImageFileName
// V rating
// ] imageFileName


@interface _EMBCommonSnapMetadata : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, strong, readonly)           NSString *title;
@property (nonatomic, strong, readonly)           NSString *imageFileName;
@property (nonatomic, strong, readonly, nullable) NSString *uuid;
@property (nonatomic, strong, readonly, nullable) NSString *comments;
@property (nonatomic, strong, readonly, nullable) NSNumber *rating;
@property (nonatomic, strong, readonly, nullable) NSNumber *type;
@property (nonatomic, strong, readonly, nullable) NSNumber *colourRedComponent;
@property (nonatomic, strong, readonly, nullable) NSNumber *colourGreenComponent;
@property (nonatomic, strong, readonly, nullable) NSNumber *colourBlueComponent;
@property (nonatomic, strong, readonly, nullable) NSDate *date;
@property (nonatomic, strong, readonly, nullable) NSString *compositedImageFileName;
@property (nonatomic, strong, readonly, nullable) NSString *webArchiveFileName;
@property (nonatomic, strong, readonly, nullable) NSURL *url;
@property (nonatomic, strong, readonly, nullable) NSArray<NSString *> *tags;

@property (nonatomic, readonly) NSSize *imageDimensions;

@property (nonatomic, readonly) BOOL hasAnnoations;
@property (nonatomic, readonly) BOOL layered;
@property (nonatomic, readonly) BOOL colorAnalysed;
@property (nonatomic, readonly) BOOL hasWebArchive;

@end

NS_ASSUME_NONNULL_END
