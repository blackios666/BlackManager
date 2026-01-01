#import "FilePropertiesViewController.h"
#import "UserGroupSelectionViewController.h"
#import "RootHelper.h"
#import <sys/stat.h>
#import <pwd.h>
#import <grp.h>
#import <CommonCrypto/CommonDigest.h>

@interface FilePropertiesViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *sections;
@property (nonatomic, strong) NSString *editingProperty; // "Propietario" o "Grupo"


// Propiedades del archivo
@property (nonatomic, strong) NSString *owner;
@property (nonatomic, strong) NSString *group;
@property (nonatomic, strong) NSString *permissions;
@property (nonatomic, strong) NSString *size;
@property (nonatomic, strong) NSString *modificationDate;

@property (nonatomic, strong) NSString *sha256Hash;

@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation FilePropertiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self.filePath lastPathComponent];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissViewController)];

    self.sections = [NSMutableArray array];

    [self setupTableView];
    [self setupLoadingIndicator];
    [self loadFileProperties];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (void)setupLoadingIndicator {
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.center = self.view.center;
    [self.view addSubview:self.loadingIndicator];
}

- (void)loadFileProperties {
    [self.loadingIndicator startAnimating];
    self.tableView.hidden = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:self.filePath error:nil];
        struct stat fileStat;
        stat([self.filePath UTF8String], &fileStat);

        // Propiedades básicas
        self.size = [NSByteCountFormatter stringFromByteCount:[attributes[NSFileSize] unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile];
        self.modificationDate = [NSDateFormatter localizedStringFromDate:attributes[NSFileModificationDate] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
        
        // Permisos y propietario
        self.permissions = [NSString stringWithFormat:@"%o", fileStat.st_mode & 0777];
        struct passwd *pw = getpwuid(fileStat.st_uid);
        self.owner = pw ? [NSString stringWithUTF8String:pw->pw_name] : [NSString stringWithFormat:@"%d", fileStat.st_uid];
        struct group *gr = getgrgid(fileStat.st_gid);
        self.group = gr ? [NSString stringWithUTF8String:gr->gr_name] : [NSString stringWithFormat:@"%d", fileStat.st_gid];

        self.sha256Hash = [self calculateHashForFile:self.filePath type:@"SHA256"];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self buildSections];
            [self.loadingIndicator stopAnimating];
            self.tableView.hidden = NO;
            [self.tableView reloadData];
        });
    });
}

- (void)buildSections {
    // Sección de Propiedades
    [self.sections addObject:@{
        @"title": NSLocalizedString(@"Propiedades", nil),
        @"rows": @[
            @{@"label": NSLocalizedString(@"Propietario", nil), @"value": self.owner, @"editable": @YES},
            @{@"label": NSLocalizedString(@"Grupo", nil), @"value": self.group, @"editable": @YES},
            @{@"label": NSLocalizedString(@"Permisos", nil), @"value": self.permissions, @"editable": @YES}
        ]
    }];

    // Sección de Hashes
    [self.sections addObject:@{
        @"title": NSLocalizedString(@"Hashes de Verificación", nil),
        @"rows": @[
            @{@"label": NSLocalizedString(@"SHA256", nil), @"value": self.sha256Hash, @"editable": @NO}
        ]
    }];

    // Sección de Información
    [self.sections addObject:@{
        @"title": NSLocalizedString(@"Información Adicional", nil),
        @"rows": @[
            @{@"label": NSLocalizedString(@"Tamaño", nil), @"value": self.size, @"editable": @YES},
            @{@"label": NSLocalizedString(@"Fecha de Modificación", nil), @"value": self.modificationDate, @"editable": @YES}
        ]
    }];
}

- (NSString *)calculateHashForFile:(NSString *)filePath type:(NSString *)type {
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    [inputStream open];

    if ([type isEqualToString:@"SHA256"]) {
        CC_SHA256_CTX sha256Context;
        CC_SHA256_Init(&sha256Context);
        uint8_t buffer[1024];
        NSInteger bytesRead;
        while ((bytesRead = [inputStream read:buffer maxLength:1024]) > 0) {
            CC_SHA256_Update(&sha256Context, buffer, (CC_LONG)bytesRead);
        }
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(digest, &sha256Context);
        NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
            [output appendFormat:@"%02x", digest[i]];
        }
        [inputStream close];
        return output;
    }
    [inputStream close];
    return @"No Soportado";
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PropertyCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }

    NSDictionary *rowData = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.textLabel.text = rowData[@"label"];
    cell.detailTextLabel.text = rowData[@"value"];
    
    if ([rowData[@"editable"] boolValue]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *rowData = self.sections[indexPath.section][@"rows"][indexPath.row];

    NSString *label = rowData[@"label"];
    NSString *currentValue = rowData[@"value"];

    if ([label isEqualToString:@"Propietario"] || [label isEqualToString:@"Grupo"]) {
        self.editingProperty = label;
        UserGroupSelectionViewController *selectionVC = [[UserGroupSelectionViewController alloc] init];
        selectionVC.delegate = self;
        selectionVC.selectedValue = currentValue;
        selectionVC.title = [NSString stringWithFormat:NSLocalizedString(@"Seleccionar %@", nil), label];

        if ([label isEqualToString:@"Propietario"]) {
            selectionVC.data = @[@"root", @"mobile", @"_usbmuxd", @"daemon", @"_wireless", @"_networkd", @"_installd"];
        } else {
            selectionVC.data = @[@"wheel", @"staff", @"mobile", @"media", @"_usbmuxd", @"admin", @"_lp", @"_appstore", @"_analytics", @"_diagnostics", @"_wireless", @"_networkd", @"_installd"];
        }
        
        [self.navigationController pushViewController:selectionVC animated:YES];

    } else if ([label isEqualToString:@"Permisos"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Editar %@", nil), label] message:NSLocalizedString(@"Ingrese los permisos en formato octal (e.g., 755)", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.text = currentValue;
            textField.delegate = self;
            textField.keyboardType = UIKeyboardTypeNumberPad;
        }];

        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Guardar", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *newValue = alert.textFields.firstObject.text;
            [self saveProperty:label withValue:newValue];
        }]];

        [self presentViewController:alert animated:YES completion:nil];
    } else if ([label isEqualToString:@"Fecha de Modificación"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Editar %@", label] message:nil preferredStyle:UIAlertControllerStyleActionSheet]; // Use ActionSheet for UIDatePicker

        UIDatePicker *datePicker = [[UIDatePicker alloc] init];
        datePicker.datePickerMode = UIDatePickerModeDateAndTime;
        datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels; // Modern style
        
        // Set current date if available
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        NSDate *currentDate = [formatter dateFromString:currentValue];
        if (currentDate) {
            datePicker.date = currentDate;
        }

        // Add the date picker to the alert
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view = datePicker;
        vc.preferredContentSize = CGSizeMake(320, 200); // Adjust size as needed
        [alert setValue:vc forKey:@"contentViewController"];

        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Guardar", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSDateFormatter *saveFormatter = [[NSDateFormatter alloc] init];
            saveFormatter.dateStyle = NSDateFormatterShortStyle;
            saveFormatter.timeStyle = NSDateFormatterShortStyle;
            NSString *newDateString = [saveFormatter stringFromDate:datePicker.date];
            [self saveProperty:label withValue:newDateString];
        }]];

        [self presentViewController:alert animated:YES completion:nil];
    } else if ([label isEqualToString:@"Tamaño"]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:self.filePath error:nil];
        unsigned long long fileSize = [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
        NSString *fullSizeString = [NSString stringWithFormat:NSLocalizedString(@"%llu bytes", nil), fileSize];

        [self showToast:[NSString stringWithFormat:NSLocalizedString(@"Tamaño completo: %@", nil), fullSizeString]];
    }
}

#pragma mark - UserGroupSelectionDelegate

- (void)userGroupSelectionController:(UserGroupSelectionViewController *)controller didSelectValue:(NSString *)value {
    if (self.editingProperty) {
        [self saveProperty:self.editingProperty withValue:value];
        self.editingProperty = nil;
    }
}

- (void)saveProperty:(NSString *)property withValue:(NSString *)value {
    NSString *result;
    if ([property isEqualToString:@"Propietario"]) {
        result = [RootHelper changeOwnerOf:self.filePath to:value];
    } else if ([property isEqualToString:@"Grupo"]) {
        result = [RootHelper changeGroupOf:self.filePath to:value];
    } else if ([property isEqualToString:@"Permisos"]) {
        result = [RootHelper changePermissionsOf:self.filePath to:value];
    } else if ([property isEqualToString:@"Fecha de Modificación"]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        NSDate *newDate = [formatter dateFromString:value];
        if (newDate) {
            result = [RootHelper changeModificationDateOf:self.filePath to:newDate];
        } else {
            result = @"1"; // Indicate error if date parsing fails
        }
    }

    if (result && [result isEqualToString:@"0"]) {
        [self showToast:[NSString stringWithFormat:NSLocalizedString(@"%@ actualizado", nil), property]];
        [self loadFileProperties]; // Recargar todo
    } else {
        [self showError:[NSString stringWithFormat:NSLocalizedString(@"Error al actualizar %@", nil), property]];
    }
}

#pragma mark - Actions

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helpers

- (void)showToast:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    int duration = 1; // duración en segundos
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
