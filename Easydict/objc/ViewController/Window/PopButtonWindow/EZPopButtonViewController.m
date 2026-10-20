//
//  EZSelectTextPopViewController.m
//  Easydict
//
//  Created by tisfeng on 2022/11/17.
//  Copyright © 2022 izual. All rights reserved.
//

#import "EZPopButtonViewController.h"

static CGFloat kPopButtonWidth = 23;

@interface EZPopButtonViewController ()

@end

@implementation EZPopButtonViewController

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, kPopButtonWidth, kPopButtonWidth)];
    self.view.wantsLayer = YES;
    self.view.layer.cornerRadius = 5;
    self.view.layer.masksToBounds = YES;
    self.view.layer.backgroundColor = NSColor.clearColor.CGColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    EZButton *button = [[EZButton alloc] initWithFrame:self.view.bounds];
    NSImage *image = [NSImage imageNamed:@"blue-white-icon"];
    NSAttributedString *marker = [[NSAttributedString alloc] initWithString:@"ME" attributes:@{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightHeavy],
        NSForegroundColorAttributeName: NSColor.whiteColor,
    }];
    // Compose a local badge without changing the shared artwork or the hover target's size.
    button.normalImage = [NSImage imageWithSize:button.bounds.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [image drawInRect:rect];
        NSRect badgeRect = NSMakeRect(4, 2, 17, 10);
        NSBezierPath *badge = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:2.5 yRadius:2.5];
        [[NSColor colorWithSRGBRed:0.06 green:0.17 blue:0.39 alpha:1] setFill];
        [badge fill];
        [NSColor.whiteColor setStroke];
        badge.lineWidth = 0.75;
        [badge stroke];
        NSSize markerSize = marker.size;
        [marker drawAtPoint:NSMakePoint(NSMidX(badgeRect) - markerSize.width / 2,
                                       NSMidY(badgeRect) - markerSize.height / 2)];
        return YES;
    }];
    button.backgroundColor = NSColor.clearColor;
    self.popButton = button;
    [self.view addSubview:button];
    button.center = self.view.center;
}

@end
