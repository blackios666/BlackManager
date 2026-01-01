#import "AppListViewController.h"
#import "FileBrowserViewController.h"
#import "AppIcon.h"
#import "Typography.h"

// --- Declaración de APIs Privadas ---
// Necesitamos declarar las interfaces para que el compilador las conozca.
@interface LSApplicationProxy : NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
- (NSString *)localizedName;
- (NSString *)applicationIdentifier;
- (NSURL *)dataContainerURL;
- (NSData *)iconDataForVariant:(int)variant;
- (NSURL *)bundleContainerURL;
- (NSURL *)bundleURL;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end
// --- Fin de Declaración ---


@interface AppListViewController ()
@property (nonatomic, strong) NSArray<LSApplicationProxy *> *apps;
@property (nonatomic, strong) NSArray<LSApplicationProxy *> *filteredApps;
@property (nonatomic, strong) UILabel *creditsFooterLabel;
@end

@implementation AppListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Aplicaciones";
    self.navigationController.navigationBar.titleTextAttributes = @{NSFontAttributeName: [Typography titleMedium]};

    // Obtener la lista de todas las aplicaciones instaladas
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
    NSArray<LSApplicationProxy *> *allApps = [workspace allInstalledApplications];

    // Filtrar para mostrar solo aplicaciones de usuario
    NSPredicate *userAppPredicate = [NSPredicate predicateWithFormat:@"applicationType == 'User'"];
    self.apps = [allApps filteredArrayUsingPredicate:userAppPredicate];

    // Ordenar la lista alfabéticamente por nombre
    self.apps = [self.apps sortedArrayUsingComparator:^NSComparisonResult(LSApplicationProxy *obj1, LSApplicationProxy *obj2) {
        return [[obj1 localizedName] localizedCaseInsensitiveCompare:[obj2 localizedName]];
    }];

    // Inicializar filteredApps
    self.filteredApps = self.apps;

    // Configurar controlador de búsqueda
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.placeholder = @"Buscar aplicaciones";
    self.navigationItem.searchController = searchController;
    self.definesPresentationContext = YES;

    [self.tableView reloadData];

    // Footer de crédito: aparece sólo al llegar al final al hacer scroll
    self.creditsFooterLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
    self.creditsFooterLabel.text = @"Developed by black ios";
    self.creditsFooterLabel.textAlignment = NSTextAlignmentCenter;
    self.creditsFooterLabel.font = [Typography labelSmall];
    if (@available(iOS 13.0, *)) self.creditsFooterLabel.textColor = [UIColor secondaryLabelColor];
    else self.creditsFooterLabel.textColor = [UIColor grayColor];
    self.creditsFooterLabel.alpha = 0.0;
    self.tableView.tableFooterView = self.creditsFooterLabel;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        // Usar estilo default (sin identifier visible)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    }
    

    
    LSApplicationProxy *app = self.filteredApps[indexPath.row];
    
    // Asignar el nombre de la app
    cell.textLabel.text = [app localizedName];
    cell.textLabel.font = [Typography bodyLarge];
    
    // Asignar el ícono de la app (mejorado)
    NSDictionary *appInfo = [PSAppIcon getAppByPath:[app bundleURL].path];
    UIImage *iconImage = [PSAppIcon getIconForApp:appInfo bundle:[app applicationIdentifier] path:[app bundleURL].path size:40];
    if (iconImage) {
        // Resize a 32x32 para consistencia
        CGSize imgSize = CGSizeMake(32, 32);
        UIGraphicsBeginImageContextWithOptions(imgSize, NO, 0.0);
        [iconImage drawInRect:CGRectMake(0, 0, imgSize.width, imgSize.height)];
        UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        cell.imageView.image = [resized imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        // Fallback to iconDataForVariant if available
        NSData *iconData = [app iconDataForVariant:2];
        if (iconData) {
            UIImage *img = [UIImage imageWithData:iconData];
            if (img) {
                CGSize imgSize = CGSizeMake(32, 32);
                UIGraphicsBeginImageContextWithOptions(imgSize, NO, 0.0);
                [img drawInRect:CGRectMake(0, 0, imgSize.width, imgSize.height)];
                UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                cell.imageView.image = [resized imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            } else {
                UIImage *defaultAppIcon = [UIImage systemImageNamed:@"app"];
                if (defaultAppIcon) {
                    cell.imageView.image = [defaultAppIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                    if (@available(iOS 13.0, *)) {
                        cell.imageView.tintColor = [UIColor systemBlueColor];
                    } else {
                        cell.imageView.tintColor = [UIColor blueColor];
                    }
                } else {
                    cell.imageView.image = [UIImage systemImageNamed:@"app"]; // Ícono por defecto
                }
            }
        } else {
            UIImage *defaultAppIcon = [UIImage systemImageNamed:@"app"];
            if (defaultAppIcon) {
                cell.imageView.image = [defaultAppIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                if (@available(iOS 13.0, *)) {
                    cell.imageView.tintColor = [UIColor systemBlueColor];
                } else {
                    cell.imageView.tintColor = [UIColor blueColor];
                }
            } else {
                cell.imageView.image = [UIImage systemImageNamed:@"app"]; // Ícono por defecto
            }
        }
    }

    // Estilizar la imageView
    cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    cell.imageView.layer.cornerRadius = 5.0f;
    cell.imageView.clipsToBounds = YES;

    // Ya no mostramos el bundle identifier como subtítulo

    // Accesibilidad
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@", [app localizedName]];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LSApplicationProxy *selectedApp = self.filteredApps[indexPath.row];

    // Mostrar el nombre de la app como título del action sheet
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[selectedApp localizedName] message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    // Opción de Bundle
    NSString *bundleTitle = @"Bundle";
    if (@available(iOS 13.0, *)) {
        UIAlertAction *bundleAction = [UIAlertAction actionWithTitle:bundleTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *bundleURL = [selectedApp bundleContainerURL];
            if (bundleURL.path) {
                FileBrowserViewController *fileBrowser = [[FileBrowserViewController alloc] init];
                fileBrowser.currentPath = bundleURL.path;
                fileBrowser.customTitle = [NSString stringWithFormat:@"%@ - Bundle", [selectedApp localizedName]];
                [self.navigationController pushViewController:fileBrowser animated:YES];
            }
        }];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
            UIImage *img = [UIImage systemImageNamed:@"folder" withConfiguration:config];
            @try {
                [bundleAction setValue:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"image"];
            } @catch (NSException *exception) {
                // Image property not available at runtime; ignore
            }
        }
        [alert addAction:bundleAction];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"📁 %@", bundleTitle] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *bundleURL = [selectedApp bundleContainerURL];
            if (bundleURL.path) {
                FileBrowserViewController *fileBrowser = [[FileBrowserViewController alloc] init];
                fileBrowser.currentPath = bundleURL.path;
                fileBrowser.customTitle = [NSString stringWithFormat:@"%@ - Bundle", [selectedApp localizedName]];
                [self.navigationController pushViewController:fileBrowser animated:YES];
            }
        }]];
    }

    // Opción de Datos
    NSString *dataTitle = @"Datos";
    if (@available(iOS 13.0, *)) {
        UIAlertAction *dataAction = [UIAlertAction actionWithTitle:dataTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *dataURL = [selectedApp dataContainerURL];
            if (dataURL.path) {
                FileBrowserViewController *fileBrowser = [[FileBrowserViewController alloc] init];
                fileBrowser.currentPath = dataURL.path;
                fileBrowser.customTitle = [NSString stringWithFormat:@"%@ - Datos", [selectedApp localizedName]];
                [self.navigationController pushViewController:fileBrowser animated:YES];
            }
        }];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
        UIImage *img = [UIImage systemImageNamed:@"tray.full" withConfiguration:config];
        @try {
            [dataAction setValue:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"image"];
        } @catch (NSException *exception) {
            // Image property not available at runtime; ignore
        }
        [alert addAction:dataAction];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"📂 %@", dataTitle] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *dataURL = [selectedApp dataContainerURL];
            if (dataURL.path) {
                FileBrowserViewController *fileBrowser = [[FileBrowserViewController alloc] init];
                fileBrowser.currentPath = dataURL.path;
                fileBrowser.customTitle = [NSString stringWithFormat:@"%@ - Datos", [selectedApp localizedName]];
                [self.navigationController pushViewController:fileBrowser animated:YES];
            }
        }]];
    }

    // Cancelar
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
        UIImage *img = [UIImage systemImageNamed:@"xmark" withConfiguration:config];
        @try {
            [cancelAction setValue:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forKey:@"image"];
        } @catch (NSException *exception) {
            // Image property not available at runtime; ignore
        }
    }
    [alert addAction:cancelAction];

    if (@available(iOS 13.0, *)) {
        alert.view.tintColor = [UIColor systemBlueColor];
    }

    [self presentViewController:alert animated:YES completion:nil];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Mostrar el footer solo cuando el usuario llega al final haciendo scroll
    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat visibleHeight = self.tableView.bounds.size.height;
    if (contentHeight > visibleHeight) {
        CGFloat bottomOffset = scrollView.contentOffset.y + visibleHeight;
        CGFloat threshold = 10.0;
        if (bottomOffset >= contentHeight - threshold) {
            if (self.creditsFooterLabel.alpha < 1.0) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.creditsFooterLabel.alpha = 1.0;
                }];
            }
        } else {
            if (self.creditsFooterLabel.alpha > 0.0) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.creditsFooterLabel.alpha = 0.0;
                }];
            }
        }
    } else {
        if (self.creditsFooterLabel.alpha > 0.0) {
            [UIView animateWithDuration:0.2 animations:^{
                self.creditsFooterLabel.alpha = 0.0;
            }];
        }
    }
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    if (searchText.length == 0) {
        self.filteredApps = self.apps;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"localizedName CONTAINS[cd] %@", searchText];
        self.filteredApps = [self.apps filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

@end
