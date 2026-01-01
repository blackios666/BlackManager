#import "PlistEditorViewController.h"
#import "Typography.h"
#import "PlistItemCell.h"

@interface PlistEditorViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, strong) UIBarButtonItem *saveButton;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray *filteredKeys;
@end

@interface PlistEditorViewController (Private)
- (void)showTypeSelectionForKey:(NSString *)key currentValue:(id)value;
- (NSData *)dataFromHexString:(NSString *)hexString;
@end

@implementation PlistEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = [self.filePath lastPathComponent];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Load plist data
    [self loadPlistData];

    // Setup navigation bar
    self.addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem)];
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(savePlist)];
    self.navigationItem.rightBarButtonItems = @[self.saveButton, self.addButton];

    // Setup search controller
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = NSLocalizedString(@"Search keys", nil);
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    self.filteredKeys = self.currentKeys;

    // Setup table view
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.tableView registerClass:[PlistItemCell class] forCellReuseIdentifier:@"PlistItemCell"];
    [self.view addSubview:self.tableView];

    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }
}

- (void)loadPlistData {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.filePath options:0 error:&error];
    if (data) {
        id plistObject = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:NULL error:&error];
        if ([plistObject isKindOfClass:[NSDictionary class]]) {
            self.plistData = [plistObject mutableCopy];
            self.currentKeys = [self.plistData.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            self.isRootLevel = YES;
        } else if ([plistObject isKindOfClass:[NSArray class]]) {
            // Convert array to dictionary for editing
            self.plistData = [NSMutableDictionary dictionary];
            for (NSInteger i = 0; i < [plistObject count]; i++) {
                self.plistData[[NSString stringWithFormat:@"Item %ld", (long)i]] = plistObject[i];
            }
            self.currentKeys = [self.plistData.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            self.isRootLevel = YES;
        }
    }

    if (!self.plistData) {
        self.plistData = [NSMutableDictionary dictionary];
        self.currentKeys = @[];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Could not load plist file", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)addItem {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add Item", nil) message:NSLocalizedString(@"Enter key name", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:nil];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *key = alert.textFields.firstObject.text;
        if (key.length > 0 && ![self.plistData.allKeys containsObject:key]) {
            self.plistData[key] = @"";
            [self updateKeys];
            [self.tableView reloadData];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)savePlist {
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:self.plistData format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];

    if (data) {
        [data writeToFile:self.filePath atomically:YES];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Success", nil) message:NSLocalizedString(@"Plist saved successfully", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)updateKeys {
    self.currentKeys = [self.plistData.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (self.searchController.isActive) {
        [self updateSearchResultsForSearchController:self.searchController];
    }
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    if (searchText.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", searchText];
        self.filteredKeys = [self.currentKeys filteredArrayUsingPredicate:predicate];
    } else {
        self.filteredKeys = self.currentKeys;
    }
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchController.isActive ? self.filteredKeys.count : self.currentKeys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PlistCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    NSArray *keys = self.searchController.isActive ? self.filteredKeys : self.currentKeys;
    NSString *key = keys[indexPath.row];
    id value = self.plistData[key];

    cell.textLabel.text = key;
    cell.textLabel.font = [Typography bodyMedium];

    [self configureCell:cell forValue:value];

    return cell;
}

- (void)configureCell:(UITableViewCell *)cell forValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"String: %@", value];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage systemImageNamed:@"text.quote"];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        if (strcmp([value objCType], @encode(BOOL)) == 0) {
            cell.detailTextLabel.text = [value boolValue] ? @"Boolean: true" : @"Boolean: false";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage systemImageNamed:@"checkmark.circle"];
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Number: %@", value];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage systemImageNamed:@"number"];
        }
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Dictionary (%lu items)", (unsigned long)[value count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage systemImageNamed:@"list.bullet"];
    } else if ([value isKindOfClass:[NSArray class]]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Array (%lu items)", (unsigned long)[value count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage systemImageNamed:@"list.dash"];
    } else if ([value isKindOfClass:[NSDate class]]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Date: %@", [formatter stringFromDate:value]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage systemImageNamed:@"calendar"];
    } else if ([value isKindOfClass:[NSData class]]) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Data (%lu bytes)", (unsigned long)[value length]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage systemImageNamed:@"doc"];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Unknown: %@", [value class]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [UIImage systemImageNamed:@"questionmark"];
    }

    cell.detailTextLabel.font = [Typography labelSmall];
    if (@available(iOS 13.0, *)) {
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *keys = self.searchController.isActive ? self.filteredKeys : self.currentKeys;
    NSString *key = keys[indexPath.row];
    id value = self.plistData[key];

    if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
        // Navigate to nested structure
        PlistEditorViewController *nestedController = [[PlistEditorViewController alloc] init];
        nestedController.filePath = self.filePath;
        nestedController.plistData = [value mutableCopy];
        nestedController.isRootLevel = NO;
        nestedController.title = key;
        [self.navigationController pushViewController:nestedController animated:YES];
    } else {
        // Edit value
        [self editValueForKey:key currentValue:value];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)editValueForKey:(NSString *)key currentValue:(id)value {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit Value", nil) message:[NSString stringWithFormat:NSLocalizedString(@"Key: %@", nil), key] preferredStyle:UIAlertControllerStyleAlert];

    if ([value isKindOfClass:[NSString class]]) {
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.text = value;
        }];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        if (strcmp([value objCType], @encode(BOOL)) == 0) {
            // For boolean, no text field needed
        } else {
            [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.text = [value stringValue];
                textField.keyboardType = UIKeyboardTypeDecimalPad;
            }];
        }
    } else if ([value isKindOfClass:[NSDate class]]) {
        // For date editing, we could add a date picker, but for simplicity use text input
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.text = [value description];
        }];
    } else if ([value isKindOfClass:[NSData class]]) {
        // For data, show hex representation
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.text = [[value description] stringByReplacingOccurrencesOfString:@" " withString:@""];
        }];
    }

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Change Type", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showTypeSelectionForKey:key currentValue:value];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newValue = alert.textFields.firstObject.text;
        if ([value isKindOfClass:[NSString class]]) {
            self.plistData[key] = newValue;
        } else if ([value isKindOfClass:[NSNumber class]]) {
            if (strcmp([value objCType], @encode(BOOL)) == 0) {
                // Toggle boolean
                self.plistData[key] = @(![value boolValue]);
            } else {
                NSNumber *number = @([newValue doubleValue]);
                self.plistData[key] = number;
            }
        } else if ([value isKindOfClass:[NSDate class]]) {
            // Simple date parsing - in a real app you'd want better date handling
            self.plistData[key] = [NSDate date];
        } else if ([value isKindOfClass:[NSData class]]) {
            // Parse hex data
            self.plistData[key] = [self dataFromHexString:newValue];
        }
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *key = self.currentKeys[indexPath.row];
        [self.plistData removeObjectForKey:key];
        [self updateKeys];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark - Private Methods

- (void)showTypeSelectionForKey:(NSString *)key currentValue:(id)value {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Type", nil) message:NSLocalizedString(@"Choose the new type for this value", nil) preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"String", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.plistData[key] = @"";
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Number", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.plistData[key] = @0;
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Boolean", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.plistData[key] = @NO;
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Date", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.plistData[key] = [NSDate date];
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Data", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.plistData[key] = [NSData data];
        [self.tableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (NSData *)dataFromHexString:(NSString *)hexString {
    NSMutableData *data = [NSMutableData new];
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    unsigned int temp;
    while ([scanner scanHexInt:&temp]) {
        unsigned char byte = temp;
        [data appendBytes:&byte length:1];
    }
    return data;
}

@end
