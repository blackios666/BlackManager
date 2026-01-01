// UIApplication+Utilities.h

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (Utilities)

// respring()
- (void)respring;

// exitGracefully()
- (void)exitGracefully;

// checkSandbox()
- (BOOL)checkSandbox;

// Métodos y propiedades deprecated necesarios para respring
- (void)respringDeprecated;

@end

NS_ASSUME_NONNULL_END
</file_content>
</create_file>
