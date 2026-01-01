#import "SettingsManager.h"

NSString *const kShowHiddenFilesKey = @"ShowHiddenFiles";
NSString *const kUseTrashKey = @"UseTrash";
NSString *const kLanguageKey = @"SelectedLanguage";

@interface SettingsManager ()
@end

@implementation SettingsManager

+ (NSString *)ShowHiddenFilesKey { return kShowHiddenFilesKey; }
+ (NSString *)UseTrashKey { return kUseTrashKey; }
+ (NSString *)LanguageKey { return kLanguageKey; }

+ (instancetype)sharedManager {
    static SettingsManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SettingsManager alloc] init];
        [shared registerDefaults];
    });
    return shared;
}

- (void)registerDefaults {
    NSDictionary *defaults = @{
        kShowHiddenFilesKey: @NO,
        kUseTrashKey: @YES,
        kLanguageKey: @"system"
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (BOOL)showHiddenFiles {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kShowHiddenFilesKey];
}

- (void)setShowHiddenFiles:(BOOL)show {
    [[NSUserDefaults standardUserDefaults] setBool:show forKey:kShowHiddenFilesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)useTrash {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUseTrashKey];
}

- (void)setUseTrash:(BOOL)use {
    [[NSUserDefaults standardUserDefaults] setBool:use forKey:kUseTrashKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)selectedLanguage {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:kLanguageKey];
    return v ?: @"system";
}

- (void)setSelectedLanguage:(NSString *)lang {
    if (!lang) return;
    [[NSUserDefaults standardUserDefaults] setObject:lang forKey:kLanguageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
