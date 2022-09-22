//
//  SSCrashReporter.m
//  SSCrashReporter
//
//  Created by Dante Sabatier on 1/2/13.
//  Copyright (c) 2013 Dante Sabatier. All rights reserved.
//

#import "SSCrashReporter.h"
#import <SSMessage/SSMessage.h>

#define __DEBUGGING_CRASH_REPORTER_INTERFACE 0

NSString *const SSCrashReporterApplicationVersionCheckPointPreferencesKey = @"SSCrashReporterApplicationVersionCheckPoint";
NSString *const SSCrashReporterDefaultApplicationVersionKey = @"0.1";

@interface SSCrashReporter ()

@end

@implementation SSCrashReporter

static BOOL sharedCrashReporterCanBeDestroyed = NO;
static SSCrashReporter *sharedCrashReporter = nil;

+ (instancetype)sharedCrashReporter {
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedCrashReporter = [[self alloc] init];
        __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillTerminateNotification object:NSApp queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            
            sharedCrashReporterCanBeDestroyed = YES;
            
            [sharedCrashReporter release];
        }];
    });
	return sharedCrashReporter;
}

+ (instancetype)crashReporterWithMessageAddressee:(id<SSMessageAddressee>)messageAddressee messageText:(NSString *)messageText informativeTextWithFormat:(NSString *)format, ... {
    SSCrashReporter *crashReporter = [[SSCrashReporter alloc] init];
    crashReporter.messageAddressee = messageAddressee;
    crashReporter.messageText = messageText;
    if (format) {
        va_list args;
        va_start(args, format);
        NSString *informationalText = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        crashReporter.informativeText = informationalText;
        
        [informationalText release];
    }
    return [crashReporter autorelease];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [NSBundle loadNibNamed:@"CrashReporter" owner:self];
        
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
            window.animationBehavior = NSWindowAnimationBehaviorAlertPanel;
        }
        
        commentsTextView.font = [NSFont fontWithName:@"Monaco" size:10.0];
        commentsTextView.string = @"";
        reportTextView.font = commentsTextView.font;
        reportTextView.string = @"";
        
        imageView.image = NSApplication.sharedApplication.applicationIconImage;
        messageTextField.stringValue = [NSString stringWithFormat:SSLocalizedString(@"%@ has encountered a crash report that has not been sent. Would you like to send the report to developer now?", @"crash reporter message text"), (NSBundle.mainBundle.infoDictionary)[(NSString *)kCFBundleNameKey]];
        informativeTextField.stringValue = SSLocalizedString(@"Information sent through the crash reporter is used for debugging purposes only.", @"crash reporter informative text");
    }
    return self;
}

- (void)dealloc {
    if (self == sharedCrashReporter && !sharedCrashReporterCanBeDestroyed) {
        return;
    }
    
    [_messageAddressee release];
    [_helpAnchor release];
	
	[super ss_dealloc];
}

- (void)layout {
    static const CGFloat spacing = 8.0;
    static const CGFloat minimumButtonWidth = 82.0;
    static const CGFloat minimumHeight = 170.0;
    static const CGFloat buttonHeight = 32.0;
    static const CGFloat inset = 20.0;
    
    CGFloat height = inset;
    NSView *contentView = window.contentView;
    NSArray *textFields = @[messageTextField, informativeTextField];
    for (NSTextField *textField in textFields) {
        NSRect frame = textField.frame;
        frame.size.height = CGFLOAT_MAX;
        frame.size = [textField.cell cellSizeForBounds:frame];
        frame.origin.y -= floor(frame.size.height - textField.frame.size.height);
        
        textField.frame = NSIntegralRect(NSMakeRect(NSMinX(frame), NSMaxY(contentView.frame) - NSHeight(frame) - height, NSWidth(frame), NSHeight(frame)));
        
		height += NSHeight(frame) + spacing;
    }
    
    height += (((inset*(CGFloat)2.0) + buttonHeight) - spacing) + (detailsView.isHidden ? 0 : NSHeight(detailsView.frame));
    
    NSRect frame = [window frameRectForContentRect:NSMakeRect(NSMinX(window.frame), NSMinY(window.frame), NSWidth(window.frame), MAX(floor(height), minimumHeight))];
    
    [window setFrame:frame display:YES];
    
    CGFloat originX = NSMaxX(contentView.frame) - inset;
    NSArray *buttons = [[contentView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^(NSView *subview, NSDictionary *bindings) {
        return [subview isKindOfClass:NSButton.class];
    }]] sortedArrayUsingDescriptors:@[[[[NSSortDescriptor alloc] initWithKey:@"tag" ascending:YES] autorelease]]];
    for (NSButton *button in buttons) {
        [button sizeToFit];
        
        NSRect buttonFrame = button.frame;
        buttonFrame.size.width = MAX(NSWidth(buttonFrame), minimumButtonWidth);
        buttonFrame.origin.y = floor((NSMinY(contentView.frame) + (inset - spacing) + (buttonHeight*(CGFloat)0.5)) - (NSHeight(buttonFrame)*(CGFloat)0.5));
        
        switch (button.tag) {
            case 0:
            case 1:
                buttonFrame.origin.x = floor(originX - NSWidth(buttonFrame));
                break;
            case 2:
                buttonFrame.origin.x = NSMaxX(imageView.frame);
                break;
            case 3:
                buttonFrame.size.width = NSHeight(buttonFrame);
                buttonFrame.origin.x = NSMinX(imageView.frame);
                break;
        }
        
        button.frame = buttonFrame;
        
        originX -= NSWidth(buttonFrame);
    }
}

- (void)stopModalWithCode:(NSInteger)returnCode {
    if (window.isSheet) {
        [window close];
        [NSApp endSheet:window returnCode:returnCode];
    } else {
        [NSApp stopModalWithCode:returnCode];
    }
}

#if NS_BLOCKS_AVAILABLE

- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^)(NSInteger result))handler {
    [self layout];
    [NSApp beginSheet:window modalForWindow:docWindow modalDelegate:self didEndSelector:@selector(blockSheetDidEnd:returnCode:contextInfo:) contextInfo:Block_copy((__bridge void *)handler)];
}

- (void)blockSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    void (^block)(NSInteger returnCode) = (__bridge void (^)(NSInteger))(contextInfo);
    block(returnCode);
    Block_release((__bridge void *)block);
}

#endif

#pragma mark actions

- (IBAction)ok:(id)sender {
	[self stopModalWithCode:NSOKButton];
    
#if !__DEBUGGING_CRASH_REPORTER_INTERFACE
	id <SSMessageAddressee> messageAddressee = self.messageAddressee;
    if (messageAddressee) {
        NSBundle *mainBundle = NSBundle.mainBundle;
        NSString *bundleName = (mainBundle.infoDictionary)[(NSString *)kCFBundleNameKey];
        NSString *bundleShortVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *bundleVersion = [mainBundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        NSString *messageSubject = [NSString stringWithFormat:@"%@ %@ (build %@) Crash Report", bundleName, bundleShortVersion, bundleVersion];
        NSString *report = self.report;
        NSMutableString *messageBody = [NSMutableString string];
        NSString *comments = self.comments;
        if (comments.length) {
            [messageBody appendFormat:@"Comments:%@%@", comments, report.length ? @"\n\n" : @""];
        }
        
        [messageBody appendString:report];
        
        if (messageBody.length) {
            NSDictionary *messageHeaders = @{SSMessageHeaderKeySubject: messageSubject, SSMessageHeaderKeyToRecipients: @[messageAddressee]};
            NSAttributedString *content = [[[NSAttributedString alloc] initWithString:messageBody] autorelease];
            SSMessage *message = [[[SSMessage alloc] initWithHeaders:messageHeaders content:content format:SSMessageFormatPlainText] autorelease];
            [SSMessageDelivery.sharedMessageDelivery asynchronousyDeliverMessage:message completion:^(SSMessage *message, SSMessageDeliveryResult result, NSError *__nullable error) {
                if (error) {
                    NSLog(@"%@ %@ %@", self.class, NSStringFromSelector(_cmd), error);
                } 
            }];
        }
    }
#endif
}

- (IBAction)cancel:(id)sender {
	[self stopModalWithCode:NSCancelButton];
}

#pragma mark actions

- (IBAction)toggleDetails:(id)sender {
	NSView *contentView = window.contentView;
	NSRect contentViewFrame = contentView.frame;
	NSRect windowFrame = window.frame;
	NSRect detailsFrame = detailsView.frame;
	NSRect referenceFrame = [contentView convertRectToBase:informativeTextField.frame];
	
	if (![contentView.subviews containsObject:detailsView]) {
		contentViewFrame.size.height += NSHeight(detailsFrame);
		detailsFrame.origin.y = NSMinY(referenceFrame) - NSHeight(detailsFrame);
		
		windowFrame.size.height += NSHeight(detailsFrame);
		windowFrame.origin.y -= NSHeight(detailsFrame);
        
        detailsView.frame = detailsFrame;
        
        detailsView.hidden = NO;
		[contentView addSubview:detailsView positioned:NSWindowBelow relativeTo:informativeTextField];
	} else {
        detailsView.hidden = YES;
		[detailsView removeFromSuperview];
        
		contentViewFrame.size.height -= NSHeight(detailsFrame);
		
		windowFrame.size.height -= NSHeight(detailsFrame);
		windowFrame.origin.y += NSHeight(detailsFrame);
	}
	
	[window setFrame:windowFrame display:YES animate:window.isVisible];
    
    contentView.frame = contentViewFrame;
	[contentView displayIfNeeded];
}

- (IBAction)showHelp:(id)sender {
    NSString *helpAnchor = self.helpAnchor;
    if (helpAnchor.length) {
        [[NSHelpManager sharedHelpManager] openHelpAnchor:helpAnchor inBook:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"]];
    }
}

#pragma mark getters && setters

- (NSInteger)runModal {
    [self layout];
    
	[window center];
	[window makeKeyAndOrderFront:self];
	
	NSInteger response = [NSApp runModalForWindow:window];
	
	[window orderOut:nil];
	
	return response;
}

- (NSInteger)runModalIfNeeded {
#if __DEBUGGING_CRASH_REPORTER_INTERFACE
	return self.runModal;
#else
    if (!self.messageAddressee) {
        return NSCancelButton;
    }
#if 1
    if (!SSMessageIsInternetConnectionUp()) {
        return NSCancelButton;
    }
#endif
    
    NSComparisonResult (^compareAppVersions)(NSString *currentVersion, NSString *latestVersion) = ^NSComparisonResult(NSString *currentVersion, NSString *latestVersion) {
        NSArray *current = [currentVersion componentsSeparatedByString:@"."];
        NSArray *latest = [latestVersion componentsSeparatedByString:@"."];
        NSInteger idx, currentCount = current.count, latestCount = latest.count;
        for (idx = 0; idx < currentCount && idx < latestCount; idx++) {
            NSInteger c = [current[idx] integerValue];
            NSInteger l = [latest[idx] integerValue];
            if (c < l) {
                return NSOrderedAscending;
            } else if (c > l) {
                return NSOrderedDescending;
            }
        }
        
        if (idx < latestCount) {
            return NSOrderedAscending;
        }
        
        return NSOrderedSame;
    };
    
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSString *bundleName = (mainBundle.infoDictionary)[(NSString *)kCFBundleNameKey];
	NSString *bundleVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *latestVersion = [[NSUserDefaults standardUserDefaults] stringForKey:SSCrashReporterApplicationVersionCheckPointPreferencesKey] ? [[NSUserDefaults standardUserDefaults] stringForKey:SSCrashReporterApplicationVersionCheckPointPreferencesKey] : SSCrashReporterDefaultApplicationVersionKey;
	BOOL removeReports = (compareAppVersions(bundleVersion, latestVersion) == NSOrderedDescending);
    if (removeReports) {
        [[NSUserDefaults standardUserDefaults] setObject:bundleVersion forKey:SSCrashReporterApplicationVersionCheckPointPreferencesKey];
    }
    
    BOOL (^validateFilename)(NSString *filename, NSString *prefix, NSString *suffix) = ^BOOL(NSString *filename, NSString *prefix, NSString *suffix) {
        if (![filename hasPrefix:prefix] || ![filename hasSuffix:suffix]) {
            return NO;
        }
        return YES;
    };
    
    BOOL (^trashItemAtPath)(NSString *path) = ^BOOL(NSString *path) {
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_7) {
            return [[NSFileManager defaultManager] trashItemAtURL:[NSURL fileURLWithPath:path] resultingItemURL:NULL error:NULL];
        }
        return [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:path.stringByDeletingLastPathComponent destination:@"" files:(path.lastPathComponent != nil) ? @[path.lastPathComponent] : nil tag:NULL];
    };
    
    NSString *(^newestItemOfTypeInDirectory)(NSString *directory, NSString *extension) = ^NSString *(NSString *directory, NSString *extension) {
        NSString *path = nil;
        NSDate *baseDate = [NSDate dateWithTimeIntervalSince1970:0];
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
        for (NSString *filename in contents) {
            if (!validateFilename(filename, bundleName, extension)) {
                continue;
            }
            
            NSString *proposedPath = [directory stringByAppendingPathComponent:filename];
            if (removeReports) {
                trashItemAtPath(proposedPath);
            } else {
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:proposedPath error:NULL];
                if (!attributes) {
                    continue;
                }
                
                NSDate *creationDate = attributes.fileCreationDate;
                if ([baseDate compare:creationDate] == NSOrderedAscending) {
                    baseDate = creationDate;
                    path = proposedPath;
                }
            }
        }
        return path;
    };
    
	NSString *reportPath = nil;
    NSString *libraryPath = [[[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL] path];
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        NSString *path = newestItemOfTypeInDirectory([[libraryPath stringByAppendingPathComponent:@"Application Support"] stringByAppendingPathComponent:@"CrashReporter"], @"plist");
        if (path) {
            if (removeReports) {
                trashItemAtPath(path);
            } else {
                reportPath = [([NSDictionary dictionaryWithContentsOfFile:path])[@"Path"] stringByStandardizingPath];
                trashItemAtPath(path);
            }
        }
    } else {
        reportPath = newestItemOfTypeInDirectory([[libraryPath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:@"CrashReporter"], @"crash");
    }
        
    if (![[NSFileManager defaultManager] fileExistsAtPath:reportPath]) {
        return NSCancelButton;
    }
    
	NSString *report = [[[NSString alloc] initWithContentsOfFile:reportPath encoding:NSASCIIStringEncoding error:NULL] autorelease];
    if (!report.length) {
        return NSCancelButton;
    }
    
    reportTextView.string = report;
    
    trashItemAtPath(reportPath);
    
	return self.runModal;
#endif
}

- (id<SSMessageAddressee>)messageAddressee {
    return _messageAddressee;
}

- (void)setMessageAddressee:(id<SSMessageAddressee>)messageAddressee {
    SSNonAtomicCopiedSet(_messageAddressee, messageAddressee);
}

- (NSImage *)icon {
    return imageView.image;
}

- (void)setIcon:(NSImage *)icon {
    imageView.image = icon;
}

- (NSString *)messageText {
    return messageTextField.stringValue;
}

- (void)setMessageText:(NSString *)messageText {
    messageTextField.stringValue = messageText;
}

- (NSString *)informativeText {
    return informativeTextField.stringValue;
}

- (void)setInformativeText:(NSString *)informativeText {
    informativeTextField.stringValue = informativeText;
}

- (NSString *)comments {
    return commentsTextView.string;
}

- (void)setComments:(NSString *)comments {
    commentsTextView.string = comments;
}

- (NSString *)report {
    return reportTextView.string;
}

- (void)setReport:(NSString *)report {
    reportTextView.string = report;
}

- (NSString *)helpAnchor {
    return _helpAnchor;
}

- (void)setHelpAnchor:(NSString *)helpAnchor {
    SSNonAtomicCopiedSet(_helpAnchor, helpAnchor);
}

- (BOOL)showsHelp {
    return _showsHelp;
}

- (void)setShowsHelp:(BOOL)showsHelp {
    _showsHelp = showsHelp;
}

@end
