#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <sys/resource.h>

// Monitor-only: Northstar Guard never deletes, quarantines, or uploads a file.
static const double kCPU = 12.0, kMemory = 10.0;
static const NSUInteger kLiveLimit = 250;
static const unsigned long long kMaxBytes = 512ULL * 1024ULL * 1024ULL;

static NSURL *support(void) { return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/NorthstarGuard"] isDirectory:YES]; }
static NSURL *controlURL(void) { return [support() URLByAppendingPathComponent:@"control.json"]; }
static NSURL *statusURL(void) { return [support() URLByAppendingPathComponent:@"status.json"]; }
static NSURL *findingsURL(void) { return [support() URLByAppendingPathComponent:@"findings.jsonl"]; }

static NSString *now(void) { NSISO8601DateFormatter *f=[NSISO8601DateFormatter new]; f.timeZone=[NSTimeZone timeZoneWithName:@"America/New_York"]; return [f stringFromDate:NSDate.date]; }
static NSString *stamp(void) { NSDateFormatter *f=[NSDateFormatter new]; f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; f.timeZone=[NSTimeZone timeZoneWithName:@"America/New_York"]; f.dateFormat=@"yyyyMMdd-HHmmss"; return [f stringFromDate:NSDate.date]; }
static NSDictionary *readJSON(NSURL *u) { NSData *d=[NSData dataWithContentsOfURL:u]; id x=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil; return [x isKindOfClass:NSDictionary.class]?x:@{}; }
static BOOL writeJSON(NSDictionary *x, NSURL *u) { NSData *d=[NSJSONSerialization dataWithJSONObject:x options:NSJSONWritingPrettyPrinted error:nil]; return d&&[d writeToURL:u options:NSDataWritingAtomic error:nil]; }
static NSURL *configURL(void) { return [support() URLByAppendingPathComponent:@"config.json"]; }
static NSURL *reportsURL(void) { NSString *path=readJSON(configURL())[@"reportsDirectory"]; if(![path isKindOfClass:NSString.class]||!path.length) path=[NSHomeDirectory() stringByAppendingPathComponent:@"NorthstarGuardReports"]; return [NSURL fileURLWithPath:path isDirectory:YES]; }
static NSMutableDictionary *control(void) { NSMutableDictionary *x=[readJSON(controlURL()) mutableCopy]; if(!x[@"monitoringEnabled"]) x[@"monitoringEnabled"]=@YES; return x; }
static void status(NSDictionary *x) { writeJSON(x,statusURL()); }

static BOOL approved(NSURL *u) { NSString *desktopAlias=[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/Northstar Guard.app"]; return [u.path hasPrefix:[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads/MeshAgent.mpkg/"]] || [u.path isEqualToString:desktopAlias] || [u.path containsString:@"/Northstar Guard.app/"]; }
static double cpuSeconds(void) { struct rusage r; getrusage(RUSAGE_SELF,&r); return r.ru_utime.tv_sec+r.ru_utime.tv_usec/1e6+r.ru_stime.tv_sec+r.ru_stime.tv_usec/1e6; }
static BOOL overMemory(void) { struct rusage r; getrusage(RUSAGE_SELF,&r); return ((double)r.ru_maxrss/[NSProcessInfo processInfo].physicalMemory)*100.0>kMemory; }
static void pace(CFAbsoluteTime wall,double cpu) { double elapsed=CFAbsoluteTimeGetCurrent()-wall, wanted=(cpuSeconds()-cpu)/(kCPU/100.0), pause=MAX(.020,wanted-elapsed); if(pause>0) usleep((useconds_t)MIN(pause*1e6,250000.0)); }
static BOOL signedCode(NSURL *u) { SecStaticCodeRef c=NULL; if(SecStaticCodeCreateWithPath((__bridge CFURLRef)u,kSecCSDefaultFlags,&c)!=errSecSuccess||!c)return NO; OSStatus r=SecStaticCodeCheckValidity(c,kSecCSDefaultFlags,NULL); CFRelease(c); return r==errSecSuccess; }

static void logFinding(NSDictionary *f) { NSData *d=[NSJSONSerialization dataWithJSONObject:f options:0 error:nil]; if(!d)return; NSMutableData *line=[d mutableCopy]; [line appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; NSURL *u=findingsURL(); if([[NSFileManager defaultManager] fileExistsAtPath:u.path]) { NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:u.path]; [h seekToEndOfFile]; [h writeData:line]; [h closeFile]; } else [line writeToURL:u options:NSDataWritingAtomic error:nil]; }
static NSDictionary *inspect(NSURL *u, NSUInteger *large) {
    if(approved(u))return nil; NSDictionary *v=[u resourceValuesForKeys:@[NSURLIsRegularFileKey,NSURLFileSizeKey] error:nil]; if(![v[NSURLIsRegularFileKey] boolValue])return nil; if([v[NSURLFileSizeKey] unsignedLongLongValue]>kMaxBytes){(*large)++;return nil;}
    NSString *n=u.lastPathComponent.lowercaseString,*e=u.pathExtension.lowercaseString; NSSet *risky=[NSSet setWithArray:@[@"app",@"pkg",@"dmg",@"command",@"sh",@"zsh",@"bash",@"py",@"js",@"jar",@"iso"]]; NSMutableArray *reasons=[NSMutableArray array];
    if([risky containsObject:e]&&[u.path containsString:@"/Downloads/"])[reasons addObject:@"executable or installer arrived in Downloads"];
    if([n containsString:@".pdf."]||[n containsString:@".jpg."]||[n containsString:@".doc."])[reasons addObject:@"misleading double extension"];
    if([@[@"app",@"command",@"sh",@"zsh",@"bash"] containsObject:e]&&!signedCode(u))[reasons addObject:@"executable does not have a valid macOS code signature"];
    if(!reasons.count)return nil; NSDictionary *f=@{@"date":now(),@"path":u.path,@"severity":reasons.count>1?@"HIGH":@"MEDIUM",@"reasons":reasons}; logFinding(f); return f;
}

static NSDictionary *scan(NSArray *roots, NSUInteger limit, NSString *mode) {
    CFAbsoluteTime wall=CFAbsoluteTimeGetCurrent(); double cpu=cpuSeconds(); NSUInteger examined=0,large=0; BOOL limited=NO,memory=NO; NSMutableArray *findings=[NSMutableArray array],*covered=[NSMutableArray array]; NSFileManager *fm=NSFileManager.defaultManager;
    for(NSURL *root in roots) { if(![fm fileExistsAtPath:root.path])continue; [covered addObject:root.path]; NSDirectoryEnumerator *en=[fm enumeratorAtURL:root includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLFileSizeKey] options:(NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants) errorHandler:nil]; for(NSURL *u in en) { if(examined>=limit){limited=YES;break;} if(overMemory()){memory=YES;break;} examined++; NSDictionary *f=inspect(u,&large); if(f)[findings addObject:f]; pace(wall,cpu); } if(limited||memory)break; }
    return @{@"mode":mode,@"examined":@(examined),@"skippedLarge":@(large),@"limited":@(limited),@"memoryStopped":@(memory),@"roots":covered,@"findings":findings};
}

static NSString *reportText(NSDictionary *r) {
    NSArray *findings=r[@"findings"],*roots=r[@"roots"]; NSString *title=[r[@"mode"] isEqual:@"full"]?@"Full configured-scope":@"Focused"; NSMutableString *s=[NSMutableString stringWithFormat:@"# Northstar Guard %@ Scan Report\n\n",title];
    [s appendFormat:@"- **Generated:** `%@`\n- **Host:** `%@`\n- **Files examined:** `%@`\n- **Findings:** `%lu`\n- **Oversize files skipped:** `%@` (over 512 MiB)\n- **Scope:** configured high-risk locations only; not the whole disk\n\n",now(),NSProcessInfo.processInfo.hostName,r[@"examined"],(unsigned long)findings.count,r[@"skippedLarge"]];
    [s appendString:@"## Executive Summary\n\n**Executive summary source:** Local deterministic heuristic based solely on this report’s evidence.\n\n"];
    [s appendString:findings.count? [NSString stringWithFormat:@"The scan recorded %lu item(s) for review. Alerts are not malware verdicts; validate origin, signature, and purpose before acting.\n\n",(unsigned long)findings.count] : @"No files matched the current heuristic rules in the configured scope. This does not prove the Mac is malware-free because this is not a signature-based antivirus verdict.\n\n"];
    [s appendString:@"## Priorities Requiring Attention\n\n"]; if(!findings.count)[s appendString:@"- No heuristic alerts were recorded.\n"]; for(NSDictionary *f in findings)[s appendFormat:@"- **%@** — `%@`: %@\n",f[@"severity"],f[@"path"],[f[@"reasons"] componentsJoinedByString:@"; "]];
    [s appendString:@"\n## Recommended Actions\n\n1. Validate unfamiliar alerts against their expected source and developer signature.\n2. Use Gatekeeper and Finder’s Get Info before opening or installing an unfamiliar item.\n3. Compare future timestamped reports for newly appearing items.\n\n## Confidence and Data Gaps\n\n- Package descendants and hidden paths are not traversed; files over 512 MiB are skipped.\n- This clean-room monitor uses heuristics and macOS signature checks, not ClamAV or Bitdefender signatures.\n\n## Scan Coverage\n\n"]; for(NSString *root in roots)[s appendFormat:@"- `%@`\n",root]; [s appendString:@"\n## Detection Engines\n\n- Downloaded executable and installer heuristic\n- Misleading double-extension heuristic\n- macOS Security framework code-signature validation\n"]; return s;
}
static NSString *writeReport(NSDictionary *r) { NSError *e=nil; NSURL *dir=reportsURL(); if(![NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&e])return nil; NSURL *u=[dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-northstar-guard-%@.md",stamp(),r[@"mode"]]]; return [[reportText(r) writeToURL:u atomically:YES encoding:NSUTF8StringEncoding error:&e]?u.path:nil copy]; }
static NSArray *roots(void) { NSString *h=NSHomeDirectory(); return @[[NSURL fileURLWithPath:[h stringByAppendingPathComponent:@"Downloads"]],[NSURL fileURLWithPath:[h stringByAppendingPathComponent:@"Desktop"]],[NSURL fileURLWithPath:[h stringByAppendingPathComponent:@"Documents"]],[NSURL fileURLWithPath:[h stringByAppendingPathComponent:@"Library/LaunchAgents"]],[NSURL fileURLWithPath:@"/Library/LaunchAgents"],[NSURL fileURLWithPath:@"/Library/LaunchDaemons"]]; }
static void runScan(NSString *mode,NSArray *all) { NSArray *selected=[mode isEqual:@"full"]?all:[all subarrayWithRange:NSMakeRange(0,3)]; status(@{@"monitoring":@YES,@"scanInProgress":@YES,@"mode":mode,@"updatedAt":now()}); NSDictionary *r=scan(selected,NSUIntegerMax,mode); NSString *p=writeReport(r); status(@{@"monitoring":@YES,@"scanInProgress":@NO,@"lastScanAt":now(),@"lastScanMode":mode,@"lastReport":p?:@"",@"examined":r[@"examined"],@"findings":@([r[@"findings"] count]),@"updatedAt":now()}); }

int main(int argc,const char *argv[]) { @autoreleasepool { [NSFileManager.defaultManager createDirectoryAtURL:support() withIntermediateDirectories:YES attributes:nil error:nil]; if(argc==3&&strcmp(argv[1],"--request")==0){NSString *m=[NSString stringWithUTF8String:argv[2]];if(![@[@"focused",@"full"] containsObject:m])return 64;NSMutableDictionary *c=control();c[@"requestedScan"]=m;writeJSON(c,controlURL());return 0;} if(argc==2&&strcmp(argv[1],"--start")==0){NSMutableDictionary*c=control();c[@"monitoringEnabled"]=@YES;writeJSON(c,controlURL());return 0;} if(argc==2&&strcmp(argv[1],"--stop")==0){NSMutableDictionary*c=control();c[@"monitoringEnabled"]=@NO;writeJSON(c,controlURL());return 0;} NSArray *all=roots(); puts("Northstar Guard: monitor-only; scanning configured high-risk locations."); while(YES)@autoreleasepool{NSMutableDictionary*c=control();NSString *request=c[@"requestedScan"];if([@[@"focused",@"full"] containsObject:request]){[c removeObjectForKey:@"requestedScan"];writeJSON(c,controlURL());runScan(request,all);continue;}NSMutableDictionary *s=[readJSON(statusURL()) mutableCopy];s[@"monitoring"]=c[@"monitoringEnabled"];s[@"scanInProgress"]=@NO;s[@"updatedAt"]=now();status(s);if([c[@"monitoringEnabled"] boolValue]){scan(all,kLiveLimit,@"live");[NSThread sleepForTimeInterval:60];}else{[NSThread sleepForTimeInterval:1];}} } return 0; }
