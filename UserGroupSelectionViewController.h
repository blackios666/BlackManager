// UserGroupSelectionViewController.h

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class UserGroupSelectionViewController;

@protocol UserGroupSelectionDelegate <NSObject>
- (void)userGroupSelectionController:(UserGroupSelectionViewController *)controller didSelectValue:(NSString *)value;
@end

@interface UserGroupSelectionViewController : UITableViewController

@property (nonatomic, weak) id<UserGroupSelectionDelegate> delegate;
@property (nonatomic, strong) NSArray<NSString *> *data;
@property (nonatomic, strong) NSString *selectedValue;

@end

NS_ASSUME_NONNULL_END
