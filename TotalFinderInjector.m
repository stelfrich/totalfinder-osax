#import "TFStandardVersionComparator.h"

#define TOTALFINDER_PLUGIN_PATH @"/Applications/TotalFinder.app/Contents/Resources/TotalFinder.bundle"
#define FINDER_MIN_ALLOWED_VERSION @"10.6"
#define FINDER_MAX_ALLOWED_VERSION @"10.6.6"

// SIMBL-compatible interface
@interface TotalFinderPlugin: NSObject { 
}
- (void) install;
@end

static bool alreadyLoaded = false;

OSErr HandleInitEvent(const AppleEvent *ev, AppleEvent *reply, long refcon) {
    NSLog(@"TotalFinderInjector: got init request");
    if (alreadyLoaded) {
        NSLog(@"TotalFinderInjector: TotalFinder has been already loaded. Ignoring this request.");
        return noErr;
    }
    @try {
        NSBundle* finderBundle = [NSBundle mainBundle];
        if (!finderBundle) {
            NSLog(@"TotalFinderInjector: Unable to locate main Finder bundle!");
            return 4;
        }
        
        NSString* finderVersion = [finderBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
        if (!finderVersion) {
            NSLog(@"TotalFinderInjector: Unable to determine Finder version!");
            return 5;
        }
        
        // future compatibility check
        NSString* supressKey = @"TotalFinderSuppressFinderVersionCheck";
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:supressKey]) {
            TFStandardVersionComparator* comparator = [TFStandardVersionComparator defaultComparator];
            if (([comparator compareVersion:finderVersion toVersion:FINDER_MAX_ALLOWED_VERSION]==NSOrderedDescending) || 
                ([comparator compareVersion:finderVersion toVersion:FINDER_MIN_ALLOWED_VERSION]==NSOrderedAscending)) {

                NSAlert* alert = [NSAlert new];
                [alert setMessageText: [NSString stringWithFormat:@"You have Finder version %@", finderVersion]];
                [alert setInformativeText: [NSString stringWithFormat:@"But TotalFinder was properly tested only with Finder versions in range %@ - %@\n\nYou have probably updated your system and Finder version got bumped by Apple developers.\n\nYou may expect a new TotalFinder release soon.", FINDER_MIN_ALLOWED_VERSION, FINDER_MAX_ALLOWED_VERSION]];
                [alert setShowsSuppressionButton:YES];
                [alert addButtonWithTitle:@"Launch TotalFinder anyway"];
                [alert addButtonWithTitle:@"Cancel"];
                NSInteger res = [alert runModal];
                if ([[alert suppressionButton] state] == NSOnState) {
                    [defaults setBool:YES forKey:supressKey];
                }
                if (res!=NSAlertFirstButtonReturn) { // cancel
                    return noErr;
                }
            }
        }
        
        NSBundle* pluginBundle = [NSBundle bundleWithPath:TOTALFINDER_PLUGIN_PATH];
        if (!pluginBundle) {
            NSLog(@"TotalFinderInjector: Unable to load bundle from path: %@", TOTALFINDER_PLUGIN_PATH);
            return 2;
        }
        TotalFinderPlugin* principalClass = (TotalFinderPlugin*)[pluginBundle principalClass];
        if (!principalClass) {
            NSLog(@"TotalFinderInjector: Unable to retrieve principalClass for bundle: %@", pluginBundle);
            return 3;
        }
        if ([principalClass respondsToSelector:@selector(install)]) {
            NSLog(@"TotalFinderInjector: Installing TotalFinder ...");
            [principalClass install];
        }
        alreadyLoaded = true;
        return noErr;
    } @catch (NSException* exception) {
        NSLog(@"TotalFinderInjector: Failed to load TotalFinder with exception: %@", exception);
    }
    return 1;
}