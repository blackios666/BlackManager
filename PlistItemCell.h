#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlistItemCell : UITableViewCell

@property (nonatomic, strong) UIImageView *typeIconView;
@property (nonatomic, strong) UILabel *keyLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UILabel *valuePreviewLabel;
@property (nonatomic, strong) UIView *typeIndicatorView;

- (void)configureWithKey:(NSString *)key value:(id)value;

@end

NS_ASSUME_NONNULL_END
