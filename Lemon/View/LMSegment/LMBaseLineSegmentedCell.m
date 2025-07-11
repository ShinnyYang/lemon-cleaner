//
//  LMBaseLineSegmentedCell.m
//  Lemon
//

//  Copyright © 2019 Tencent. All rights reserved.
//

#import "LMBaseLineSegmentedCell.h"
#import <QMUICommon/NSFontHelper.h>
#import <QMUICommon/NSFont+LineHeight.h>
#import <QMUICommon/LMAppThemeHelper.h>
#import <QMCoreFunction/NSColor+Extension.h>


static CGFloat const kSelectedLineWidth = 1.5; // 选中线条宽度
static CGFloat const kDivisionLineWidth = 1; // 底部分割线

@interface LMBaseLineSegmentedCell ()

@property(nonatomic, strong) NSDictionary* __redPointDict;

@end

@implementation LMBaseLineSegmentedCell



- (void)drawSegment:(NSInteger)segment inFrame:(NSRect)frame withView:(NSView *)controlView{
    

    frame.origin.y += 1;
    
    
    NSColor *highlightedColor = [LMAppThemeHelper getTitleColor];
    NSColor *highlightedBaselineColor = [NSColor colorWithHex:0xFFAA09];
    NSColor *normalColor = [NSColor colorWithHex:0x94979B];
    
    NSColor *color = segment == self.selectedSegment ? highlightedColor : normalColor;
    
    NSFont *textFont = [NSFontHelper getLightSystemFont:14];
    if(segment == self.selectedSegment){
        textFont = [NSFontHelper getRegularSystemFont:14];
    }
    
    
    [color set];
    NSMutableParagraphStyle * paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingHead;
    NSDictionary * attributes = @{NSParagraphStyleAttributeName: paragraphStyle,
                                  NSForegroundColorAttributeName : color,
                                  NSFontAttributeName: textFont};
    
    frame.origin.y += 2;
    NSString *label = [self labelForSegment:segment];
    // calculate vertical center
    
    
    //    CGFloat pointSize = textFont.pointSize;
    //    CGFloat lineHeight = textFont.lineHeight;
    
    NSRect drawRect = NSInsetRect(frame, 0,  (frame.size.height - textFont.lineHeight)/2 - 1 );
    [label drawInRect:drawRect withAttributes:attributes];
    
    if(segment == self.selectedSegment){
        [self __saveSegmentSelectedState:label];    // 如果选中过，有红点以后不要再显示
        
        NSRect labelRect = [label boundingRectWithSize:frame.size options:0 attributes:attributes];
        
        CGFloat lineOriginY = 0;
        CGFloat lineOriginX = frame.origin.x + (frame.size.width - labelRect.size.width)/2;
        if ([[NSGraphicsContext currentContext] isFlipped]) {
            lineOriginY = frame.size.height - kDivisionLineWidth; // 分割线若是放在segment底部，则会被segemnt的子view遮挡
        }else{
            lineOriginY = 0;
        }
        
        [highlightedBaselineColor set];
        NSBezierPath *line = [NSBezierPath bezierPath];
        [line moveToPoint:NSMakePoint(lineOriginX, lineOriginY - kSelectedLineWidth)];
        [line lineToPoint:NSMakePoint(lineOriginX + labelRect.size.width, lineOriginY - kSelectedLineWidth)];
        line.lineWidth = kSelectedLineWidth;
        [line stroke];
    }
    
    // 判断是否显示红点
    if ([self __needShowRedPoint:label]) {
        NSImage * image = [NSImage imageNamed:@"redpoint"];
        [image drawInRect:NSMakeRect(NSMaxX(frame)-15, NSMinY(frame)+10, 10, 10)];
    }
    
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    //    NSEraseRect(cellFrame);
    //    [[NSColor clearColor] set];
    //    NSRectFillUsingOperation(cellFrame, NSCompositeOverlay);
    
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}


- (void)updateCellRedPointInfo:(NSDictionary *)redPointDict {
    self.__redPointDict = redPointDict;
}

- (BOOL)__needShowRedPoint:(NSString *)title {
    if ([title isKindOfClass:NSString.class]) {
        NSString *key = self.__redPointDict[title];
        if (key && ![[NSUserDefaults standardUserDefaults] boolForKey:key]) {
            return YES;
        }
    }
    return NO;
}

- (void)__saveSegmentSelectedState:(NSString *)title {
    if ([title isKindOfClass:NSString.class]) {
        NSString *key = self.__redPointDict[title];
        if (key && ![[NSUserDefaults standardUserDefaults] boolForKey:key]) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
        }
    }
}


@end
