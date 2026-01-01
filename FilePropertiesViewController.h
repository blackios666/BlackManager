#import <UIKit/UIKit.h>
#import "UserGroupSelectionViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface FilePropertiesViewController : UIViewController <UserGroupSelectionDelegate>

@property (nonatomic, strong) NSString *filePath;

@end

NS_ASSUME_NONNULL_END
