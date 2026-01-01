#import "TrashViewController.h"
#import "RootHelper.h"

@interface TrashViewController ()
@property (nonatomic, strong) NSArray<NSString *> *items; // file names in trash (no .meta)
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation TrashViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = NSLocalizedString(@"Papelera", nil);
        self.items = @[];
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Vaciar", nil) style:UIBarButtonItemStylePlain target:self action:@selector(emptyTrash:)];

    if (@available(iOS 10.0, *)) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(loadTrash) forControlEvents:UIControlEventValueChanged];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageChanged:) name:@"LanguageChanged" object:nil];

    [self loadTrash];
}

- (void)languageChanged:(NSNotification *)note {
    self.title = NSLocalizedString(@"Papelera", nil);
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"LanguageChanged" object:nil];
}

- (NSString *)trashDir {
    return @"/var/mobile/BlackTrash";
}

- (void)loadTrash {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self trashDir] error:&error];
        if (error) contents = @[];
        // Filter to exclude .meta files
        NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(NSString *evaluated, NSDictionary *bindings) {
            return ![evaluated hasSuffix:@".meta"];
        }];
        NSArray *files = [contents filteredArrayUsingPredicate:pred];
        // Sort by name (timestamp prefix will order by date)
        files = [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.items = files;
            [self.tableView reloadData];
            if (self.refreshControl.isRefreshing) [self.refreshControl endRefreshing];
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSString *fileName = self.items[indexPath.row];
    cell.textLabel.text = fileName;
    // Try to read original path from .meta
    NSString *metaPath = [[self trashDir] stringByAppendingPathComponent:[fileName stringByAppendingString:@".meta"]];
    NSString *orig = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:metaPath]) {
        orig = [NSString stringWithContentsOfFile:metaPath encoding:NSUTF8StringEncoding error:nil];
    }
    cell.detailTextLabel.text = orig ?: NSLocalizedString(@"Origen desconocido", nil);
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (NSArray<UIContextualAction *> *)actionsForItemAt:(NSString *)fileName {
    __weak typeof(self) weakSelf = self;
    UIContextualAction *restore = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:NSLocalizedString(@"Restaurar", nil) handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [weakSelf restoreItem:fileName];
        completionHandler(YES);
    }];
    restore.backgroundColor = [UIColor systemBlueColor];

    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:NSLocalizedString(@"Eliminar", nil) handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [weakSelf deleteItem:fileName];
        completionHandler(YES);
    }];

    return @[delete, restore];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fileName = self.items[indexPath.row];
    NSArray *acts = [self actionsForItemAt:fileName];
    UISwipeActionsConfiguration *conf = [UISwipeActionsConfiguration configurationWithActions:acts];
    return conf;
}

- (void)restoreItem:(NSString *)fileName {
    NSString *trashPath = [[self trashDir] stringByAppendingPathComponent:fileName];
    NSString *metaPath = [trashPath stringByAppendingString:@".meta"];
    NSString *orig = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:metaPath]) {
        orig = [NSString stringWithContentsOfFile:metaPath encoding:NSUTF8StringEncoding error:nil];
    }
    NSString *dest = orig ?: [@"/var/mobile/Documents" stringByAppendingPathComponent:fileName];

    // Try move via RootHelper
    NSString *result = [RootHelper moveFileFrom:trashPath to:dest];
    if (![result isEqualToString:@"0"]) {
        UIAlertController *err = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo restaurar el archivo.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [err addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:err animated:YES completion:nil];
        return;
    }
    // Remove meta
    if ([[NSFileManager defaultManager] fileExistsAtPath:metaPath]) {
        [RootHelper removeItemAt:metaPath];
    }
    [self loadTrash];
}

- (void)deleteItem:(NSString *)fileName {
    NSString *trashPath = [[self trashDir] stringByAppendingPathComponent:fileName];
    NSString *metaPath = [trashPath stringByAppendingString:@".meta"];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Eliminar", nil) message:[NSString stringWithFormat:NSLocalizedString(@"Eliminar '%@' permanentemente?", nil), fileName] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Eliminar", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [RootHelper removeItemAt:trashPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:metaPath]) [RootHelper removeItemAt:metaPath];
        [self loadTrash];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)emptyTrash:(id)sender {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Vaciar papelera", nil) message:NSLocalizedString(@"¿Eliminar todos los elementos de la papelera?", nil) preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Vaciar", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSError *err = nil;
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self trashDir] error:&err];
            if (!contents) contents = @[];
            for (NSString *name in contents) {
                NSString *full = [[self trashDir] stringByAppendingPathComponent:name];
                [RootHelper removeItemAt:full];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadTrash];
            });
        });
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

@end
