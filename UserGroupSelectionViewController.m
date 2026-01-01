// UserGroupSelectionViewController.m

#import "UserGroupSelectionViewController.h"

@implementation UserGroupSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SelectionCell"];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SelectionCell" forIndexPath:indexPath];
    NSString *value = self.data[indexPath.row];
    cell.textLabel.text = value;
    
    if ([value isEqualToString:self.selectedValue]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedValue = self.data[indexPath.row];
    [self.delegate userGroupSelectionController:self didSelectValue:selectedValue];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
