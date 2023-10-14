//
//  TableCellWithButtonView.h
//  Bothlin
//
//  Created by Michael Dales on 14/10/2023.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TableCellWithButtonView : NSTableCellView

@property (nonatomic, weak, readwrite) IBOutlet NSButton *button;

@end

NS_ASSUME_NONNULL_END
