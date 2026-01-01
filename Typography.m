#import "Typography.h"

@implementation Typography

#pragma mark - Titles

+ (UIFont *)titleLarge {
    return [self fontWithSize:28 weight:UIFontWeightBold];
}

+ (UIFont *)titleMedium {
    return [self fontWithSize:24 weight:UIFontWeightSemibold];
}

+ (UIFont *)titleSmall {
    return [self fontWithSize:20 weight:UIFontWeightSemibold];
}

#pragma mark - Headlines

+ (UIFont *)headlineLarge {
    return [self fontWithSize:20 weight:UIFontWeightSemibold];
}

+ (UIFont *)headlineMedium {
    return [self fontWithSize:18 weight:UIFontWeightSemibold];
}

+ (UIFont *)headlineSmall {
    return [self fontWithSize:16 weight:UIFontWeightMedium];
}

#pragma mark - Body Text

+ (UIFont *)bodyLarge {
    return [self fontWithSize:16 weight:UIFontWeightRegular];
}

+ (UIFont *)bodyMedium {
    return [self fontWithSize:14 weight:UIFontWeightRegular];
}

+ (UIFont *)bodySmall {
    return [self fontWithSize:12 weight:UIFontWeightRegular];
}

#pragma mark - Labels

+ (UIFont *)labelLarge {
    return [self fontWithSize:14 weight:UIFontWeightMedium];
}

+ (UIFont *)labelMedium {
    return [self fontWithSize:12 weight:UIFontWeightMedium];
}

+ (UIFont *)labelSmall {
    return [self fontWithSize:11 weight:UIFontWeightMedium];
}

#pragma mark - Helper

+ (UIFont *)fontWithSize:(CGFloat)size weight:(UIFontWeight)weight {
    return [UIFont systemFontOfSize:size weight:weight];
}

@end
