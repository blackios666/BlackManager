#import "NSBundle+Language.h"
#import <objc/runtime.h>

static const char kBundleKey;

@implementation NSBundle (Language)

+ (void)setLanguage:(NSString *)language {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod([NSBundle class], @selector(localizedStringForKey:value:table:));
        Method swizzled = class_getInstanceMethod([NSBundle class], @selector(lang_localizedStringForKey:value:table:));
        method_exchangeImplementations(original, swizzled);
    });

    NSLog(@"[NSBundle+Language] setLanguage: %@", language);

    if (!language || [language isEqualToString:@"system"]) {
        objc_setAssociatedObject([NSBundle mainBundle], &kBundleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:language ofType:@"lproj"];
    NSBundle *langBundle = path ? [NSBundle bundleWithPath:path] : nil;
    if (langBundle) {
        NSLog(@"[NSBundle+Language] using bundle at: %@", path);
    } else {
        NSLog(@"[NSBundle+Language] bundle for %@ not found, falling back", language);
    }
    objc_setAssociatedObject([NSBundle mainBundle], &kBundleKey, langBundle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Notify interested parties that the language bundle changed (for hot reload)
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChanged" object:language];
    });
}

- (NSString *)lang_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    NSBundle *bundle = objc_getAssociatedObject([NSBundle mainBundle], &kBundleKey);
    if (bundle) {
        return [bundle lang_localizedStringForKey:key value:value table:tableName];
    }
    return [self lang_localizedStringForKey:key value:value table:tableName];
}

@end
