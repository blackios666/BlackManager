#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsManager : NSObject

@property (class, nonatomic, readonly) NSString *const ShowHiddenFilesKey;
@property (class, nonatomic, readonly) NSString *const UseTrashKey;
@property (class, nonatomic, readonly) NSString *const LanguageKey;

+ (instancetype)sharedManager;

- (void)registerDefaults;

- (BOOL)showHiddenFiles;
- (void)setShowHiddenFiles:(BOOL)show;

- (BOOL)useTrash;
- (void)setUseTrash:(BOOL)use;

- (NSString *)selectedLanguage;
- (void)setSelectedLanguage:(NSString *)lang;

@end

NS_ASSUME_NONNULL_END
