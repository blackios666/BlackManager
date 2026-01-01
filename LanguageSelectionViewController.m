#import "LanguageSelectionViewController.h"
#import "SettingsManager.h"
#import "NSBundle+Language.h"

@interface LanguageSelectionViewController ()
@property (nonatomic, strong) NSArray<NSString *> *languages;
@end

@implementation LanguageSelectionViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = NSLocalizedString(@"Idioma", nil);
        self.languages = @[@"system", @"en", @"es", @"fr", @"de", @"pt", @"it", @"ja", @"tr", @"pl", @"id", @"vi", @"nl", @"zh-Hans", @"zh-Hant", @"ar", @"ru", @"hi", @"ko"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.languages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSString *code = self.languages[indexPath.row];
    NSString *label = [self displayNameForCode:code];
    cell.textLabel.text = label;
    if ([[SettingsManager sharedManager].selectedLanguage isEqualToString:code]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (NSString *)displayNameForCode:(NSString *)code {
    if ([code isEqualToString:@"system"]) return NSLocalizedString(@"Sistema", nil);
    if ([code isEqualToString:@"en"]) return NSLocalizedString(@"English", nil);
    if ([code isEqualToString:@"es"]) return NSLocalizedString(@"Español", nil);
    if ([code isEqualToString:@"fr"]) return NSLocalizedString(@"Francés", nil);
    if ([code isEqualToString:@"de"]) return NSLocalizedString(@"Alemán", nil);
    if ([code isEqualToString:@"pt"]) return NSLocalizedString(@"Portugués", nil);
    if ([code isEqualToString:@"it"]) return NSLocalizedString(@"Italiano", nil);
    if ([code isEqualToString:@"ja"]) return NSLocalizedString(@"Japonés", nil);
    if ([code isEqualToString:@"tr"]) return NSLocalizedString(@"Turco", nil);
    if ([code isEqualToString:@"pl"]) return NSLocalizedString(@"Polaco", nil);
    if ([code isEqualToString:@"id"]) return NSLocalizedString(@"Indonesio", nil);
    if ([code isEqualToString:@"vi"]) return NSLocalizedString(@"Vietnamita", nil);
    if ([code isEqualToString:@"nl"]) return NSLocalizedString(@"Holandés", nil);
    if ([code isEqualToString:@"zh-Hans"]) return NSLocalizedString(@"Chino simplificado", nil);
    if ([code isEqualToString:@"zh-Hant"]) return NSLocalizedString(@"Chino tradicional", nil);
    if ([code isEqualToString:@"ar"]) return NSLocalizedString(@"Árabe", nil);
    if ([code isEqualToString:@"ru"]) return NSLocalizedString(@"Ruso", nil);
    if ([code isEqualToString:@"hi"]) return NSLocalizedString(@"Hindi", nil);
    if ([code isEqualToString:@"ko"]) return NSLocalizedString(@"Coreano", nil);
    return code;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *code = self.languages[indexPath.row];
    // Apply language immediately so UI refreshes use the new bundle
    [NSBundle setLanguage:code];
    [[SettingsManager sharedManager] setSelectedLanguage:code];
    [tableView reloadData];
    // Notify app to rebuild UI
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SettingsChanged" object:nil];

    // Visual feedback: pop back after selection
    [self.navigationController popViewControllerAnimated:YES];
}

@end
