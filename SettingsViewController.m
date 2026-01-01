#import "SettingsViewController.h"
#import "SettingsManager.h"
#import "LanguageSelectionViewController.h"
#import "TrashViewController.h"

typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionGeneral = 0,
    SettingsSectionCount
};

@implementation SettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = NSLocalizedString(@"Ajustes", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    // Do not register class so we can use Value1 style for detail text
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageChanged:) name:@"LanguageChanged" object:nil];
}

- (void)languageChanged:(NSNotification *)note {
    self.title = NSLocalizedString(@"Ajustes", nil);
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"LanguageChanged" object:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionGeneral:
            return 4; // Idioma, Archivos ocultos, Papelera, Gestionar papelera
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    SettingsManager *mgr = [SettingsManager sharedManager];

    if (indexPath.section == SettingsSectionGeneral) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Idioma", nil);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            // Mostrar texto legible del idioma
            NSString *code = mgr.selectedLanguage;
            if ([code isEqualToString:@"system"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Sistema", nil);
            } else if ([code isEqualToString:@"en"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"English", nil);
            } else if ([code isEqualToString:@"es"]) {
                cell.detailTextLabel.text = NSLocalizedString(@"Español", nil);
            } else {
                cell.detailTextLabel.text = code;
            }
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Mostrar archivos ocultos", nil);
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [mgr showHiddenFiles];
            [sw addTarget:self action:@selector(toggleHiddenFiles:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = NSLocalizedString(@"Usar papelera", nil);
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [mgr useTrash];
            [sw addTarget:self action:@selector(toggleUseTrash:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        } else if (indexPath.row == 3) {
            cell.textLabel.text = NSLocalizedString(@"Gestionar papelera", nil);
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == SettingsSectionGeneral) {
        if (indexPath.row == 0) {
            LanguageSelectionViewController *lang = [[LanguageSelectionViewController alloc] init];
            [self.navigationController pushViewController:lang animated:YES];
        } else if (indexPath.row == 3) {
            TrashViewController *trash = [[TrashViewController alloc] init];
            [self.navigationController pushViewController:trash animated:YES];
        }
    }
}

- (void)toggleHiddenFiles:(UISwitch *)sw {
    [[SettingsManager sharedManager] setShowHiddenFiles:sw.isOn];
    // Post a notification so file browsers can refresh
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:nil];
}

- (void)toggleUseTrash:(UISwitch *)sw {
    [[SettingsManager sharedManager] setUseTrash:sw.isOn];
}

@end
