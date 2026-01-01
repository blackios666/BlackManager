#import <UIKit/UIKit.h>

@interface SQLiteViewerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSString *dbPath;

@end
