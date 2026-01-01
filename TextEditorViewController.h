#import <UIKit/UIKit.h>

@interface TextEditorViewController : UIViewController

@property (nonatomic, strong) NSString *filePath;

// UI Components
@property (nonatomic, strong) UIToolbar *bottomToolbar;
@property (nonatomic, strong) UIView *statusBar;
@property (nonatomic, strong) UILabel *statusLabel;

// State Properties
@property (nonatomic, assign) BOOL hasUnsavedChanges;
@property (nonatomic, assign) CGFloat currentFontSize;
@property (nonatomic, assign) BOOL wordWrapEnabled;
@property (nonatomic, strong) NSString *originalText;

@end
