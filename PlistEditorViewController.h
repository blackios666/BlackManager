#import <UIKit/UIKit.h>

@interface PlistEditorViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating>

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSMutableDictionary *plistData;
@property (nonatomic, strong) NSArray *currentKeys;
@property (nonatomic, assign) BOOL isRootLevel;

@end
