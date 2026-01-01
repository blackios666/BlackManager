#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Typography : NSObject

// MARK: - Titles
+ (UIFont *)titleLarge;           // 28pt, Bold
+ (UIFont *)titleMedium;          // 24pt, Semibold
+ (UIFont *)titleSmall;           // 20pt, Semibold

// MARK: - Headlines
+ (UIFont *)headlineLarge;        // 20pt, Semibold
+ (UIFont *)headlineMedium;       // 18pt, Semibold
+ (UIFont *)headlineSmall;        // 16pt, Medium

// MARK: - Body Text
+ (UIFont *)bodyLarge;            // 16pt, Regular
+ (UIFont *)bodyMedium;           // 14pt, Regular
+ (UIFont *)bodySmall;            // 12pt, Regular

// MARK: - Labels
+ (UIFont *)labelLarge;           // 14pt, Medium
+ (UIFont *)labelMedium;          // 12pt, Medium
+ (UIFont *)labelSmall;           // 11pt, Medium

// MARK: - Helper
+ (UIFont *)fontWithSize:(CGFloat)size weight:(UIFontWeight)weight;

@end

NS_ASSUME_NONNULL_END
