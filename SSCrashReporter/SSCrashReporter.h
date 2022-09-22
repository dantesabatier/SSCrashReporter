//
//  SSCrashReporter.h
//  SSCrashReporter
//
//  Created by Dante Sabatier on 1/2/13.
//  Copyright (c) 2013 Dante Sabatier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SSMessage/SSMessageAddressee.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSCrashReporter : NSObject {
@private
	IBOutlet NSWindow *window;
    IBOutlet NSImageView *imageView;
    IBOutlet NSTextField *messageTextField;
    IBOutlet NSTextField *informativeTextField;
	IBOutlet NSView *detailsView;
    IBOutlet NSTextView *reportTextView;
	IBOutlet NSTextView *commentsTextView;
    NSString *_helpAnchor;
    BOOL _showsHelp;
    id <SSMessageAddressee> _messageAddressee;
}

+ (instancetype)crashReporterWithMessageAddressee:(id<SSMessageAddressee>)messageAddressee messageText:(NSString *)messageText informativeTextWithFormat:(NSString *)format, ...;
@property (class, readonly, strong) SSCrashReporter *sharedCrashReporter;
@property (nonatomic, copy) id <SSMessageAddressee> messageAddressee;
@property (nonatomic, strong) NSImage *icon;
@property (nonatomic, strong) NSString *messageText;
@property (nonatomic, strong) NSString *informativeText;
@property (nonatomic, strong) NSString *comments;
@property (nonatomic, strong) NSString *report;
@property (nonatomic, copy) NSString *helpAnchor;
@property (nonatomic, assign) BOOL showsHelp;
@property (nonatomic, readonly) NSInteger runModal;
@property (nonatomic, readonly) NSInteger runModalIfNeeded;
#if NS_BLOCKS_AVAILABLE
#if defined(__MAC_10_9)
- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^ __nullable)(NSModalResponse response))handler NS_AVAILABLE(10_6, NA);
#else
- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^ __nullable)(NSInteger response))handler NS_AVAILABLE(10_6, NA);
#endif
#endif

@end

NS_ASSUME_NONNULL_END
