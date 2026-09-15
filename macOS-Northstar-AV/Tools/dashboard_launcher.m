#import <AppKit/AppKit.h>

@interface Dashboard : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property NSWindow *window;
@property NSTableView *table;
@property NSMutableArray *items;
@property NSTextField *summary;
@property NSTextField *monitoringLabel;
@end

@implementation Dashboard
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame size:(CGFloat)size bold:(BOOL)bold color:(NSColor *)color {
    NSTextField *field = [NSTextField labelWithString:text]; field.frame = frame;
    field.font = [NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular]; field.textColor = color; return field;
}
- (NSView *)card:(NSRect)frame {
    NSView *card = [[NSView alloc] initWithFrame:frame]; card.wantsLayer = YES;
    card.layer.backgroundColor = [[NSColor colorWithRed:.07 green:.13 blue:.22 alpha:1] CGColor]; card.layer.cornerRadius = 14;
    card.layer.borderColor = [[NSColor colorWithRed:.16 green:.28 blue:.40 alpha:1] CGColor]; card.layer.borderWidth = 1; return card;
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.items = [NSMutableArray array];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,820,600) styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable) backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Northstar Guard"; self.window.minSize = NSMakeSize(720,500);
    NSView *content = self.window.contentView; content.wantsLayer = YES; content.layer.backgroundColor = [[NSColor colorWithRed:.025 green:.055 blue:.10 alpha:1] CGColor];
    [content addSubview:[self label:@"Northstar Guard" frame:NSMakeRect(32,548,340,30) size:25 bold:YES color:NSColor.whiteColor]];
    [content addSubview:[self label:@"Local-first macOS monitoring" frame:NSMakeRect(32,524,300,20) size:13 bold:NO color:[NSColor colorWithWhite:.70 alpha:1]]];
    NSButton *refresh=[NSButton buttonWithTitle:@"Refresh" target:self action:@selector(refresh:)]; refresh.frame=NSMakeRect(642,540,76,32); [content addSubview:refresh];
    NSButton *log=[NSButton buttonWithTitle:@"Open log" target:self action:@selector(openLog:)]; log.frame=NSMakeRect(724,540,70,32); [content addSubview:log];
    NSView *status=[self card:NSMakeRect(32,420,756,84)]; NSView *dot=[[NSView alloc]initWithFrame:NSMakeRect(22,33,12,12)]; dot.wantsLayer=YES; dot.layer.backgroundColor=[[NSColor colorWithRed:.25 green:.89 blue:.64 alpha:1] CGColor]; dot.layer.cornerRadius=6; [status addSubview:dot];
    self.monitoringLabel=[self label:@"Monitoring active" frame:NSMakeRect(48,48,230,20) size:17 bold:YES color:NSColor.whiteColor]; [status addSubview:self.monitoringLabel];
    [status addSubview:[self label:@"12% CPU target · 10% RAM cap · monitor-only" frame:NSMakeRect(48,22,280,16) size:12 bold:NO color:[NSColor colorWithWhite:.72 alpha:1]]];
    NSArray *buttons=@[@[@"Start",@"startMonitoring:"],@[@"Stop",@"stopMonitoring:"],@[@"Scan now",@"scanFocused:"],@[@"Full scope",@"scanFull:"]]; CGFloat x=338; for(NSArray *spec in buttons){NSButton *b=[NSButton buttonWithTitle:spec[0] target:self action:NSSelectorFromString(spec[1])]; b.frame=NSMakeRect(x,29,98,30); [status addSubview:b]; x+=103;} [content addSubview:status];
    [content addSubview:[self label:@"Recent activity" frame:NSMakeRect(32,384,250,23) size:17 bold:YES color:NSColor.whiteColor]];
    self.summary=[self label:@"Loading findings…" frame:NSMakeRect(550,387,238,17) size:12 bold:NO color:[NSColor colorWithWhite:.68 alpha:1]]; self.summary.alignment=NSTextAlignmentRight; [content addSubview:self.summary];
    NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(32,105,756,267)]; scroll.hasVerticalScroller=YES; scroll.borderType=NSBezelBorder;
    self.table=[[NSTableView alloc]initWithFrame:scroll.bounds]; self.table.dataSource=self; self.table.delegate=self; self.table.rowHeight=32;
    for (NSArray *d in @[@[@"time",@"Time",@"145"],@[@"severity",@"Level",@"85"],@[@"path",@"Item",@"300"],@[@"detail",@"Reason",@"225"]]) { NSTableColumn *c=[[NSTableColumn alloc]initWithIdentifier:d[0]]; c.title=d[1]; c.width=[d[2] doubleValue]; [self.table addTableColumn:c]; }
    scroll.documentView=self.table; [content addSubview:scroll];
    [content addSubview:[self label:@"Scope: Downloads · Desktop · Documents · LaunchAgent and LaunchDaemon locations" frame:NSMakeRect(32,68,650,18) size:12 bold:NO color:[NSColor colorWithWhite:.68 alpha:1]]];
    [content addSubview:[self label:@"Review alerts before acting; this dashboard never changes files." frame:NSMakeRect(32,42,650,18) size:12 bold:NO color:[NSColor colorWithRed:.42 green:.76 blue:.94 alpha:1]]];
    [self reload]; [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refresh:) userInfo:nil repeats:YES]; [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)reload { [self.items removeAllObjects]; NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard/findings.jsonl"]; NSString *content=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @""; for(NSString *line in [content componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) { NSDictionary *d=[NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil]; if([d isKindOfClass:NSDictionary.class] && ![d[@"path"] containsString:@"/Northstar Guard.app/"]) [self.items addObject:d]; } if(self.items.count>80) self.items=[[self.items subarrayWithRange:NSMakeRange(self.items.count-80,80)] mutableCopy]; NSDictionary *state=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard/status.json"]] options:0 error:nil]; BOOL live=[state[@"monitoring"] boolValue]; self.monitoringLabel.stringValue=state[@"scanInProgress"]?[NSString stringWithFormat:@"%@ scan running…",state[@"mode"]?:@"On-demand"]:(live?@"Monitoring active":@"Monitoring paused"); self.summary.stringValue=[NSString stringWithFormat:@"%lu recorded findings",(unsigned long)self.items.count]; [self.table reloadData]; if(self.items.count)[self.table scrollRowToVisible:self.items.count-1]; }
- (void)refresh:(id)sender { [self reload]; }
- (void)openLog:(id)sender { [[NSWorkspace sharedWorkspace] openFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard/agent.log"] withApplication:@"Console"]; }
- (void)runAgent:(NSString *)argument { NSTask *task=[NSTask new]; task.launchPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard/northstar-guard"]; task.arguments=argument?@[argument]:@[]; @try {[task launch];} @catch(NSException *e) { self.monitoringLabel.stringValue=@"Northstar Guard service is unavailable"; } }
- (void)startMonitoring:(id)sender { [self runAgent:@"--start"]; self.monitoringLabel.stringValue=@"Starting monitoring…"; }
- (void)stopMonitoring:(id)sender { [self runAgent:@"--stop"]; self.monitoringLabel.stringValue=@"Stopping monitoring…"; }
- (void)scanFocused:(id)sender { NSTask *task=[NSTask new]; task.launchPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard/northstar-guard"]; task.arguments=@[@"--request",@"focused"]; @try {[task launch]; self.monitoringLabel.stringValue=@"Focused scan queued…";} @catch(NSException *e) {self.monitoringLabel.stringValue=@"Northstar Guard service is unavailable";} }
- (void)scanFull:(id)sender { NSTask *task=[NSTask new]; task.launchPath=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard/northstar-guard"]; task.arguments=@[@"--request",@"full"]; @try {[task launch]; self.monitoringLabel.stringValue=@"Full-scope scan queued…";} @catch(NSException *e) {self.monitoringLabel.stringValue=@"Northstar Guard service is unavailable";} }
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table { return self.items.count; }
- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row { NSTextField *f=[NSTextField labelWithString:@""]; NSDictionary *i=self.items[row]; NSString *key=column.identifier; if([key isEqual:@"time"])f.stringValue=i[@"date"]?:@"—"; else if([key isEqual:@"severity"]){f.stringValue=i[@"severity"]?:@"—";f.textColor=[[f.stringValue uppercaseString]isEqual:@"HIGH"]?NSColor.systemRedColor:NSColor.systemOrangeColor;} else if([key isEqual:@"path"])f.stringValue=[i[@"path"] lastPathComponent]?:@"—"; else f.stringValue=[i[@"reasons"] componentsJoinedByString:@"; "]?:@"—"; f.lineBreakMode=NSLineBreakByTruncatingTail; return f; }
@end
int main(int argc,const char *argv[]){ @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; Dashboard *delegate=[Dashboard new]; app.delegate=delegate; app.activationPolicy=NSApplicationActivationPolicyRegular; [app run]; } return 0; }
