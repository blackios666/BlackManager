#import "FileBrowserViewController.h"
#import "TextEditorViewController.h"
#import "PlistEditorViewController.h"
#import "AppListViewController.h"
#import "ImageViewerViewController.h"
#import "FontViewerViewController.h"
#import "SQLiteViewerViewController.h"
#import "FilePropertiesViewController.h"
#import "SSZipArchive/SSZipArchive.h"
#import <sys/stat.h>
#import <pwd.h>
#import <grp.h>
#import "RootHelper.h"
#import "Typography.h"
#import "SettingsManager.h"
#import <QuickLook/QuickLook.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <fcntl.h>
#include <unistd.h>

static NSString *pendingOperation = nil;

@interface FileBrowserViewController () <UISearchBarDelegate, QLPreviewControllerDataSource, QLPreviewControllerDelegate, UIDocumentPickerDelegate>
@property (nonatomic, strong) UIView *sortBar;
@property (nonatomic, strong) UIButton *nameSortButton;
@property (nonatomic, strong) UIButton *dateSortButton;
@property (nonatomic, strong) UIButton *sizeSortButton;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, strong) NSDate *lastRefreshDate;

// Auto-refresh: monitor directory for external changes
@property (nonatomic, assign) int monitoredDirectoryFD;
@property (nonatomic, strong) dispatch_source_t directoryMonitor;

- (void)loadFilesAndFolders;
- (void)updateRefreshTitle;
@end

@implementation FileBrowserViewController

#pragma mark - Document Picker (Import ZIP)

- (void)presentDocumentPickerForZip {
    // Importar ZIP usando UIDocumentPicker (API moderna en iOS 14+)
    if (@available(iOS 14.0, *)) {
        UTType *zipType = [UTType typeWithIdentifier:@"public.zip-archive"];
        if (!zipType) zipType = [UTType typeWithIdentifier:@"com.pkware.zip-archive"]; // fallback
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[zipType] asCopy:YES];
        picker.delegate = self;
        picker.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        NSArray *types = @[@"public.zip-archive"];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
        #pragma clang diagnostic pop
        picker.delegate = self;
        picker.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    // Copiar a temp y extraer
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:url.lastPathComponent];
    NSError *error = nil;
    BOOL accessed = [url startAccessingSecurityScopedResource];
    NSURL *destURL = [NSURL fileURLWithPath:tempPath];
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:destURL error:&error];
    if (accessed) [url stopAccessingSecurityScopedResource];

    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"No se pudo importar: %@", nil), error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Extraer el ZIP en la carpeta actual
    [self extractZipAtPath:tempPath toDestination:self.currentPath];
    // Borrar temp
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Método de conveniencia para abrir la raíz
+ (instancetype)fileBrowserForRoot {
    FileBrowserViewController *browser = [[FileBrowserViewController alloc] initWithStyle:UITableViewStylePlain];
    browser.currentPath = @"/";
    return browser;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Configurar la barra de búsqueda usando UISearchController
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.placeholder = NSLocalizedString(@"Buscar...", nil);
    searchController.searchBar.delegate = self;
    if (@available(iOS 13.0, *)) {
        searchController.searchBar.searchTextField.backgroundColor = [UIColor secondarySystemBackgroundColor];
        searchController.searchBar.searchTextField.layer.cornerRadius = 10;
        searchController.searchBar.searchTextField.layer.masksToBounds = YES;
    }
    self.navigationItem.searchController = searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.searchBar = searchController.searchBar;

    // Configurar el título de navegación con el nombre de la carpeta
    if ([self.currentPath isEqualToString:@"/"]) {
        self.navigationItem.title = NSLocalizedString(@"Raíz", nil);
    } else {
        self.navigationItem.title = [self.currentPath lastPathComponent];
    }

    // Configurar la barra de ordenamiento
    [self setupSortBar];

    // Inicializar propiedades de ordenamiento por defecto
    if (!self.sortKey) {
        self.sortKey = @"name";
        self.sortAscending = YES;
    }
    [self updateSortButtonTitles];

    // --- BOTÓN '+' MEJORADO: en iOS14+ usa UIMenu con SF Symbols; fallback usa showAddMenu ---
    if (@available(iOS 14.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];

        UIAction *pasteAction = [UIAction actionWithTitle:NSLocalizedString(@"Pegar", nil) image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [feedback impactOccurred];
            [self pasteItem];
        }];

        UIAction *newFolderAction = [UIAction actionWithTitle:NSLocalizedString(@"Nueva Carpeta", nil) image:[UIImage systemImageNamed:@"folder.badge.plus"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [feedback impactOccurred];
            [self createNewItem:YES];
        }];

        UIAction *newFileAction = [UIAction actionWithTitle:NSLocalizedString(@"Nuevo Archivo", nil) image:[UIImage systemImageNamed:@"doc.badge.plus"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [feedback impactOccurred];
            [self createNewItem:NO];
        }];

        UIAction *importZipAction = [UIAction actionWithTitle:NSLocalizedString(@"Importar ZIP", nil) image:[UIImage systemImageNamed:@"archivebox"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [feedback impactOccurred];
            [self presentDocumentPickerForZip];
        }];

        UIAction *appsAction = [UIAction actionWithTitle:NSLocalizedString(@"Ver Aplicaciones", nil) image:[UIImage systemImageNamed:@"app"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [feedback impactOccurred];
            AppListViewController *appListVC = [[AppListViewController alloc] init];
            [self.navigationController pushViewController:appListVC animated:YES];
        }];

        UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[pasteAction, newFolderAction, newFileAction, importZipAction, appsAction]];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightBold];
        UIImage *plusImage = [[UIImage systemImageNamed:@"plus.circle" withConfiguration:config] imageWithTintColor:[UIColor systemBlueColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithImage:plusImage style:UIBarButtonItemStylePlain target:nil action:nil];
        addButton.menu = menu;
        addButton.accessibilityLabel = NSLocalizedString(@"Añadir", nil);
        self.navigationItem.rightBarButtonItem = addButton;
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddMenu)];
    }

    // Configurar estilo moderno de iOS
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }

    // Configurar pull-to-refresh
    if (@available(iOS 10.0, *)) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(refreshFiles) forControlEvents:UIControlEventValueChanged];
        self.refreshControl.tintColor = [UIColor systemBlueColor];
        // Inicializar título informativo (última actualización)
        [self updateRefreshTitle];
        self.tableView.refreshControl = self.refreshControl;
        self.refreshControl.accessibilityLabel = NSLocalizedString(@"Actualizar lista", nil);
    }

    // Modern row sizing and large title appearance
    self.tableView.estimatedRowHeight = 60.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    if (@available(iOS 11.0, *)) {
        // Use standard (small) title instead of large title to keep header compact
        self.navigationController.navigationBar.prefersLargeTitles = NO;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }

    // Escuchar cambios en ajustes (p. ej. mostrar archivos ocultos)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageChanged:) name:@"LanguageChanged" object:nil];

    [self loadFilesAndFolders];
    // Start monitoring current directory for external changes
    [self startMonitoringDirectoryAtPath:self.currentPath];
}

- (void)settingsChanged:(NSNotification *)note {
    [self loadFilesAndFolders];
}

- (void)languageChanged:(NSNotification *)note {
    // Update localized UI elements and reload table
    if ([self.currentPath isEqualToString:@"/"]) {
        self.navigationItem.title = NSLocalizedString(@"Raíz", nil);
    }
    self.searchBar.placeholder = NSLocalizedString(@"Buscar...", nil);
    [self.tableView reloadData];
}
- (void)loadFilesAndFolders {
    // Leer y ordenar en un hilo de fondo para no bloquear la UI
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSError *error = nil;
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:strongSelf.currentPath error:&error];

        // Aplicar filtro según ajustes: ocultar archivos que comienzan con '.' si está desactivado
        SettingsManager *mgr = [SettingsManager sharedManager];
        if (![mgr showHiddenFiles]) {
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *bindings) {
                return ![name hasPrefix:@"."];
            }];
            contents = [contents filteredArrayUsingPredicate:predicate];
        }

        if (error) {
            // Mostrar alerta y actualizar UI en el hilo principal
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"No se pudo cargar el directorio: %@", nil), error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:alert animated:YES completion:nil];

                if (@available(iOS 10.0, *)) {
                    BOOL wasRefreshing = strongSelf.refreshControl.isRefreshing;
                    [strongSelf.refreshControl endRefreshing];
                    if (wasRefreshing) {
                        strongSelf.lastRefreshDate = [NSDate date];
                    }
                    [strongSelf updateRefreshTitle];
                }
            });
            return;
        }

        // Ordenar en background (sortedContents hace operaciones de archivo, está bien en background)
        NSArray *sorted = [strongSelf sortedContents:contents];

        // Actualizar modelo y UI en el hilo principal
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.contents = sorted;
            if (strongSelf.isSearching) {
                [strongSelf filterContentForSearchText:strongSelf.searchBar.text];
            } else {
                [strongSelf.tableView reloadData];
            }

            if (@available(iOS 10.0, *)) {
                BOOL wasRefreshing = strongSelf.refreshControl.isRefreshing;
                [strongSelf.refreshControl endRefreshing];
                if (wasRefreshing) {
                    strongSelf.lastRefreshDate = [NSDate date];
                }
                [strongSelf updateRefreshTitle];
            }
        });
    });
}

- (NSArray *)sortedContents:(NSArray *)contents {
    return [contents sortedArrayUsingComparator:^NSComparisonResult(NSString *item1, NSString *item2) {
        NSString *path1 = [self.currentPath stringByAppendingPathComponent:item1];
        NSString *path2 = [self.currentPath stringByAppendingPathComponent:item2];

        NSComparisonResult result = NSOrderedSame;

        if ([self.sortKey isEqualToString:@"name"]) {
            result = [item1 localizedCaseInsensitiveCompare:item2];
        } else if ([self.sortKey isEqualToString:@"date"]) {
            NSError *error1, *error2;
            NSDictionary *attr1 = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:&error1];
            NSDictionary *attr2 = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:&error2];
            if (!error1 && !error2) {
                NSDate *date1 = attr1[NSFileModificationDate];
                NSDate *date2 = attr2[NSFileModificationDate];
                result = [date1 compare:date2];
            }
        } else if ([self.sortKey isEqualToString:@"size"]) {
            NSError *error1, *error2;
            NSDictionary *attr1 = [[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:&error1];
            NSDictionary *attr2 = [[NSFileManager defaultManager] attributesOfItemAtPath:path2 error:&error2];
            if (!error1 && !error2) {
                NSNumber *size1 = attr1[NSFileSize];
                NSNumber *size2 = attr2[NSFileSize];
                result = [size1 compare:size2];
            }
        }

        // Invertir si es descendente
        if (!self.sortAscending) {
            if (result == NSOrderedAscending) result = NSOrderedDescending;
            else if (result == NSOrderedDescending) result = NSOrderedAscending;
        }

        return result;
    }];
}

- (void)setupSortBar {
    // Container for the sort buttons (compact when using navigation search bar)
    self.sortBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 34)];
    self.sortBar.backgroundColor = [UIColor systemBackgroundColor];
    self.sortBar.autoresizingMask = UIViewAutoresizingFlexibleWidth; 

    // Create buttons with SF Symbols and long-press to toggle direction
    // Usar símbolo más distintivo para "Nombre" y hacerlo ligeramente más destacado
    self.nameSortButton = [self createSortButtonWithTitle:NSLocalizedString(@"Nombre", nil) symbol:@"tag"];
    [self.nameSortButton addTarget:self action:@selector(sortByName) forControlEvents:UIControlEventTouchUpInside];
    // Aumentar punto/peso del símbolo para que destaque
    if (@available(iOS 15.0, *)) {
        UIImageSymbolConfiguration *boldCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
        UIImage *img = [UIImage systemImageNamed:@"tag" withConfiguration:boldCfg];
        if (img) {
            UIButtonConfiguration *cfg = self.nameSortButton.configuration ? [self.nameSortButton.configuration copy] : [UIButtonConfiguration plainButtonConfiguration];
            cfg.image = img;
            self.nameSortButton.configuration = cfg;
        }
    } else if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *boldCfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
        UIImage *img = [UIImage systemImageNamed:@"tag" withConfiguration:boldCfg];
        if (img) [self.nameSortButton setImage:img forState:UIControlStateNormal];
    }
    UILongPressGestureRecognizer *nameLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(toggleSortDirection:)];
    nameLongPress.minimumPressDuration = 0.5;
    [self.nameSortButton addGestureRecognizer:nameLongPress];
    self.nameSortButton.accessibilityHint = NSLocalizedString(@"Toca para ordenar, mantén para invertir orden", nil);

    self.dateSortButton = [self createSortButtonWithTitle:NSLocalizedString(@"Fecha", nil) symbol:@"calendar"];
    [self.dateSortButton addTarget:self action:@selector(sortByDate) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *dateLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(toggleSortDirection:)];
    dateLongPress.minimumPressDuration = 0.5;
    [self.dateSortButton addGestureRecognizer:dateLongPress];
    self.dateSortButton.accessibilityHint = NSLocalizedString(@"Toca para ordenar, mantén para invertir orden", nil);

    self.sizeSortButton = [self createSortButtonWithTitle:NSLocalizedString(@"Tamaño", nil) symbol:@"arrow.up.arrow.down.circle"];
    [self.sizeSortButton addTarget:self action:@selector(sortBySize) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *sizeLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(toggleSortDirection:)];
    sizeLongPress.minimumPressDuration = 0.5;
    [self.sizeSortButton addGestureRecognizer:sizeLongPress];
    self.sizeSortButton.accessibilityHint = NSLocalizedString(@"Toca para ordenar, mantén para invertir orden", nil); 

    // Use a stack view for layout
    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameSortButton, self.dateSortButton, self.sizeSortButton]];
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.distribution = UIStackViewDistributionFillEqually;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.spacing = 4;
    stackView.translatesAutoresizingMaskIntoConstraints = NO; 

    [self.sortBar addSubview:stackView];

    // Constraints for the stack view (padded)
    [NSLayoutConstraint activateConstraints:@[
        [stackView.leadingAnchor constraintEqualToAnchor:self.sortBar.leadingAnchor constant:8],
        [stackView.trailingAnchor constraintEqualToAnchor:self.sortBar.trailingAnchor constant:-8],
        [stackView.centerYAnchor constraintEqualToAnchor:self.sortBar.centerYAnchor],
    ]];

    // Set the sort bar as the table header view
    self.tableView.tableHeaderView = self.sortBar;
} 

- (UIButton *)createSortButtonWithTitle:(NSString *)title symbol:(NSString *)symbolName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    // Dynamic Type font
    button.titleLabel.font = [Typography labelMedium];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;

    if (@available(iOS 15.0, *)) {
        // Use modern UIButtonConfiguration for proper layout and to avoid deprecated APIs
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.title = title;

        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *symCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightRegular];
            UIImage *img = [UIImage systemImageNamed:symbolName withConfiguration:symCfg];
            if (img) cfg.image = img;
        }

        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = 2;
        cfg.baseForegroundColor = [UIColor systemBlueColor];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(2, 4, 2, 4);

        button.configuration = cfg;
        button.tintColor = [UIColor systemBlueColor];
    } else {
        // Fallback for older iOS: set title and image manually. Suppress deprecation warnings for edge insets.
        [button setTitle:title forState:UIControlStateNormal];
        [button setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];

        if (@available(iOS 13.0, *)) {
            UIImage *img = [UIImage systemImageNamed:symbolName];
            if (img) {
                UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightRegular];
                img = [img imageWithConfiguration:cfg];
                [button setImage:img forState:UIControlStateNormal];
                button.tintColor = [UIColor systemBlueColor];

                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                button.imageEdgeInsets = UIEdgeInsetsMake(0, -1, 0, 1);
                button.titleEdgeInsets = UIEdgeInsetsMake(0, 1, 0, -1);
                #pragma clang diagnostic pop
            }
        }
    }

    // Visual styling
    button.layer.cornerRadius = 4.0;
    button.clipsToBounds = YES; 
    button.backgroundColor = [UIColor clearColor];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // Accessibility
    button.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Ordenar por %@", nil), title];
    button.accessibilityHint = @"Toca para ordenar; mantén para cambiar dirección";

    return button;
}

// New sort action methods
- (void)sortByName {
    if ([self.sortKey isEqualToString:@"name"]) {
        self.sortAscending = !self.sortAscending;
    } else {
        self.sortKey = @"name";
        self.sortAscending = YES;
    }
    [self updateAndReload];
}

- (void)sortByDate {
    if ([self.sortKey isEqualToString:@"date"]) {
        self.sortAscending = !self.sortAscending;
    } else {
        self.sortKey = @"date";
        self.sortAscending = YES;
    }
    [self updateAndReload];
}

- (void)sortBySize {
    if ([self.sortKey isEqualToString:@"size"]) {
        self.sortAscending = !self.sortAscending;
    } else {
        self.sortKey = @"size";
        self.sortAscending = YES;
    }
    [self updateAndReload];
}

// Long press to toggle ascending/descending for a given sort button
- (void)toggleSortDirection:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIButton *btn = (UIButton *)gesture.view;

    if (btn == self.nameSortButton) {
        if (![self.sortKey isEqualToString:@"name"]) {
            self.sortKey = @"name";
            self.sortAscending = YES;
        } else {
            self.sortAscending = !self.sortAscending;
        }
    } else if (btn == self.dateSortButton) {
        if (![self.sortKey isEqualToString:@"date"]) {
            self.sortKey = @"date";
            self.sortAscending = YES;
        } else {
            self.sortAscending = !self.sortAscending;
        }
    } else if (btn == self.sizeSortButton) {
        if (![self.sortKey isEqualToString:@"size"]) {
            self.sortKey = @"size";
            self.sortAscending = YES;
        } else {
            self.sortAscending = !self.sortAscending;
        }
    }

    [self updateAndReload];
}

- (void)updateAndReload {
    [self updateSortButtonTitles];
    [self loadFilesAndFolders];
}

// Método para manejar la recarga (pull-to-refresh)
- (void)refreshFiles {
    if (@available(iOS 10.0, *)) {
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Actualizando...", nil) attributes:@{NSForegroundColorAttributeName: (id)[UIColor secondaryLabelColor]}];
    }
    [self loadFilesAndFolders];
} 

- (void)updateSortButtonTitles {
    NSString *direction = self.sortAscending ? @" ▲" : @" ▼";

    // Reset titles (keep direction for screen readers)
    [self.nameSortButton setTitle:[@"Nombre" stringByAppendingString:([self.sortKey isEqualToString:@"name"] ? direction : @"")] forState:UIControlStateNormal];
    [self.dateSortButton setTitle:[@"Fecha" stringByAppendingString:([self.sortKey isEqualToString:@"date"] ? direction : @"")] forState:UIControlStateNormal];
    [self.sizeSortButton setTitle:[@"Tamaño" stringByAppendingString:([self.sortKey isEqualToString:@"size"] ? direction : @"")] forState:UIControlStateNormal];

    // Visual state for selected/unselected
    NSArray *buttons = @[self.nameSortButton, self.dateSortButton, self.sizeSortButton];
    for (UIButton *btn in buttons) {
        BOOL isSelected = ((btn == self.nameSortButton && [self.sortKey isEqualToString:@"name"]) ||
                           (btn == self.dateSortButton && [self.sortKey isEqualToString:@"date"]) ||
                           (btn == self.sizeSortButton && [self.sortKey isEqualToString:@"size"]));

        if (@available(iOS 15.0, *)) {
            // Use UIButtonConfiguration to reflect selected/unselected states cleanly
            UIButtonConfiguration *cfg = btn.configuration ? [btn.configuration copy] : [UIButtonConfiguration plainButtonConfiguration];
            if (isSelected) {
                cfg.baseBackgroundColor = [UIColor systemBlueColor];
                cfg.baseForegroundColor = [UIColor whiteColor];
            } else {
                cfg.baseBackgroundColor = nil;
                cfg.baseForegroundColor = [UIColor systemBlueColor];
            }
            btn.configuration = cfg;
        } else {
            if (isSelected) {
                if (@available(iOS 13.0, *)) {
                    btn.backgroundColor = [UIColor systemBlueColor];
                    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    btn.tintColor = [UIColor whiteColor];
                } else {
                    btn.backgroundColor = [UIColor blueColor];
                    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    btn.tintColor = [UIColor whiteColor];
                }
            } else {
                btn.backgroundColor = [UIColor clearColor];
                [btn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
                btn.tintColor = [UIColor systemBlueColor];
            }
        }

        // Accessibility attributes applied regardless
        if (isSelected) {
            btn.accessibilityTraits = UIAccessibilityTraitSelected | UIAccessibilityTraitButton;
            btn.accessibilityValue = self.sortAscending ? NSLocalizedString(@"Ascendente", nil) : NSLocalizedString(@"Descendente", nil);
        } else {
            btn.accessibilityTraits = UIAccessibilityTraitButton;
            btn.accessibilityValue = @"";
        }
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterContentForSearchText:searchText];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.isSearching = YES;
    searchBar.showsCancelButton = YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    self.isSearching = NO;
    searchBar.showsCancelButton = NO;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self filterContentForSearchText:@""];
}

- (void)filterContentForSearchText:(NSString *)searchText {
    if (searchText.length == 0) {
        self.isSearching = NO;
        self.filteredContents = self.contents;
    } else {
        self.isSearching = YES;
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self CONTAINS[cd] %@", searchText];
        self.filteredContents = [self.contents filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

// --- MENÚ '+' MEJORADO ---
- (void)showAddMenu {
    // Haptics
    UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [g prepare];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    // Pegar
    UIAlertAction *pasteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Pegar", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [g impactOccurred];
        [self pasteItem];
    }];
    // Icono SF Symbol
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"doc.on.clipboard"];
        if (img) [pasteAction setValue:img forKey:@"image"];
    }
    pasteAction.accessibilityLabel = NSLocalizedString(@"Pegar desde portapapeles", nil);
    [alert addAction:pasteAction];

    // Nueva Carpeta
    UIAlertAction *newFolderAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Nueva Carpeta", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [g impactOccurred];
        [self createNewItem:YES];
    }];
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"folder.badge.plus"];
        if (img) [newFolderAction setValue:img forKey:@"image"];
    }
    newFolderAction.accessibilityLabel = NSLocalizedString(@"Crear nueva carpeta", nil);
    [alert addAction:newFolderAction];

    // Nuevo Archivo TXT
    UIAlertAction *newFileAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Nuevo Archivo TXT", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [g impactOccurred];
        [self createNewItem:NO];
    }];
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"doc.badge.plus"];
        if (img) [newFileAction setValue:img forKey:@"image"];
    }
    newFileAction.accessibilityLabel = NSLocalizedString(@"Crear nuevo archivo de texto", nil);
    [alert addAction:newFileAction];

    // Importar ZIP (document picker)
    UIAlertAction *importZipAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Importar ZIP", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [g impactOccurred];
        [self presentDocumentPickerForZip];
    }];
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"archivebox"];
        if (img) [importZipAction setValue:img forKey:@"image"];
    }
    importZipAction.accessibilityLabel = NSLocalizedString(@"Importar archivo ZIP", nil);
    [alert addAction:importZipAction];

    // Ver aplicaciones (acción existente)
    UIAlertAction *appsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Ver Aplicaciones", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [g impactOccurred];
        AppListViewController *appListVC = [[AppListViewController alloc] init];
        [self.navigationController pushViewController:appListVC animated:YES];
    }];
    appsAction.accessibilityLabel = NSLocalizedString(@"Ver lista de aplicaciones", nil);
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"app"];
        if (img) [appsAction setValue:img forKey:@"image"];
    }
    appsAction.accessibilityLabel = NSLocalizedString(@"Ver lista de aplicaciones", nil);
    [alert addAction:appsAction];

    // Cancel
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil];
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"xmark.circle"];
        if (img) [cancelAction setValue:img forKey:@"image"];
    }
    cancelAction.accessibilityLabel = NSLocalizedString(@"Cancelar", nil); // localized on purpose
    [alert addAction:cancelAction];

    // iPad: popover anchor
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.barButtonItem = self.navigationItem.rightBarButtonItem;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    // Present
    [self presentViewController:alert animated:YES completion:nil];
}

// --- MÉTODO NUEVO PARA CREAR CARPETAS Y ARCHIVOS ---
- (void)createNewItem:(BOOL)isFolder {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(isFolder ? NSLocalizedString(@"Nueva Carpeta", nil) : NSLocalizedString(@"Nuevo Archivo", nil)) message:NSLocalizedString(@"Introduce un nombre", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:nil];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length > 0) {
            NSString *path = [self.currentPath stringByAppendingPathComponent:name];
            NSString *result;

            if (isFolder) {
                result = [RootHelper createDirectoryAt:path];
            } else {
                result = [RootHelper writeString:@"" toPath:path];
            }

            if ([result isEqualToString:@"0"]) {
                [self loadFilesAndFolders];
            } else {
                UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo crear el ítem.", nil) preferredStyle:UIAlertControllerStyleAlert];
                [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errorAlert animated:YES completion:nil];
            }
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// --- MÉTODO NUEVO PARA RENOMBRAR ARCHIVOS Y CARPETAS ---
- (void)renameItemAtPath:(NSString *)fullPath {
    NSString *currentName = [fullPath lastPathComponent];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Renombrar", nil) message:NSLocalizedString(@"Introduce un nuevo nombre", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = currentName;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newName = alert.textFields.firstObject.text;
        if (newName.length > 0 && ![newName isEqualToString:currentName]) {
            NSString *newPath = [[fullPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];
            NSString *result = [RootHelper moveFileFrom:fullPath to:newPath];
            if ([result isEqualToString:@"0"]) {
                [self loadFilesAndFolders];
            } else {
                UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo renombrar.", nil) preferredStyle:UIAlertControllerStyleAlert];
                [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errorAlert animated:YES completion:nil];
            }
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// --- MÉTODO PARA EXTRAER ZIP CON RESOLUCIÓN DE CONFLICTOS ---
- (void)extractZipAtPath:(NSString *)zipPath toDestination:(NSString *)destinationPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;

    // Crear directorio temporal
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"No se pudo crear directorio temporal: %@", nil), error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        return;
    }

        // Extraer ZIP a subcarpeta con el nombre del ZIP
        NSString *zipName = [[zipPath lastPathComponent] stringByDeletingPathExtension];
        NSString *targetDir = [tempDir stringByAppendingPathComponent:zipName];
        [fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:nil error:nil];
        BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:targetDir overwrite:NO password:nil error:&error];
    if (!success) {
        [fm removeItemAtPath:tempDir error:nil]; // Limpiar temp
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"No se pudo extraer: %@", nil), error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        return;
    }



        // Mover la carpeta completa al destino
        NSString *finalFolder = [destinationPath stringByAppendingPathComponent:zipName];
        if ([fm fileExistsAtPath:finalFolder]) {
            finalFolder = [self generateUniquePathForFileAt:finalFolder];
        }
        [fm moveItemAtPath:targetDir toPath:finalFolder error:&error];
        if (error) {
            NSLog(@"Error moviendo carpeta extraída: %@", error);
        } else {
            // Aplicar propietario y permisos recursivamente para evitar que los archivos queden como root
            [self applyParentOwnershipAndPermissionsToPath:finalFolder parentPath:destinationPath];
        }
        // Limpiar directorio temporal
        [fm removeItemAtPath:tempDir error:nil];
        [self loadFilesAndFolders];
}


// --- MÉTODO PARA PEGAR CON RESOLUCIÓN DE CONFLICTOS ---
- (void)pasteItem {
    NSString *sourcePath = [UIPasteboard generalPasteboard].string;
    if (!sourcePath || sourcePath.length == 0) return;

    NSString *fileName = [sourcePath lastPathComponent];
    NSString *destinationPath = [self.currentPath stringByAppendingPathComponent:fileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:destinationPath]) {
        // Mostrar opciones de conflicto
        UIAlertController *conflictAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Archivo ya existe", nil) message:[NSString stringWithFormat:NSLocalizedString(@"'%@' ya existe en esta ubicación. ¿Qué deseas hacer?", nil), fileName] preferredStyle:UIAlertControllerStyleAlert];

        [conflictAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Reemplazar", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self performPasteWithSource:sourcePath destination:destinationPath replace:YES];
        }]];

        [conflictAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Renombrar", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *newDestinationPath = [self generateUniquePathForFileAt:destinationPath];
            [self performPasteWithSource:sourcePath destination:newDestinationPath replace:NO];
        }]];

        [conflictAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Omitir", nil) style:UIAlertActionStyleCancel handler:nil]];

        [self presentViewController:conflictAlert animated:YES completion:nil];
    } else {
        [self performPasteWithSource:sourcePath destination:destinationPath replace:NO];
    }
}

- (NSString *)generateUniquePathForFileAt:(NSString *)originalPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directory = [originalPath stringByDeletingLastPathComponent];
    NSString *fileName = [originalPath lastPathComponent];
    NSString *baseName = [fileName stringByDeletingPathExtension];
    NSString *extension = [fileName pathExtension];
    NSString *newPath;
    int counter = 1;

    do {
        NSString *newFileName = [NSString stringWithFormat:@"%@ (%d)", baseName, counter];
        if (extension.length > 0) {
            newFileName = [newFileName stringByAppendingPathExtension:extension];
        }
        newPath = [directory stringByAppendingPathComponent:newFileName];
        counter++;
    } while ([fileManager fileExistsAtPath:newPath]);

    return newPath;
}

- (void)performPasteWithSource:(NSString *)sourcePath destination:(NSString *)destinationPath replace:(BOOL)replace {
    if (replace) {
        NSString *removeResult = [RootHelper removeItemAt:destinationPath];
        if (![removeResult isEqualToString:@"0"]) {
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo reemplazar.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:errorAlert animated:YES completion:nil];
            return;
        }
    }

    NSString *pasteResult;
    if ([pendingOperation isEqualToString:@"move"]) {
        pasteResult = [RootHelper moveFileFrom:sourcePath to:destinationPath];
    } else {
        pasteResult = [RootHelper copyFileFrom:sourcePath to:destinationPath];
    }

    pendingOperation = nil;

    if ([pasteResult isEqualToString:@"0"]) {
        [self loadFilesAndFolders];
    } else {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo pegar.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
}

// Actualiza el título del RefreshControl según el estado (sin mostrar fecha)
- (void)updateRefreshTitle {
    if (!self.refreshControl) return;

    UIColor *color = nil;
    if (@available(iOS 13.0, *)) color = [UIColor secondaryLabelColor];

    if (self.refreshControl.isRefreshing) {
        if (color) {
            self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Actualizando...", nil) attributes:@{NSForegroundColorAttributeName: (id)color}];
        } else {
            self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Actualizando..."];
        }
    } else {
        // No mostrar texto cuando está idle
        self.refreshControl.attributedTitle = nil;
    }
}

#pragma mark - Directory Monitoring (auto refresh for external changes)

- (void)startMonitoringDirectoryAtPath:(NSString *)path {
    if (!path) return;

    // Stop any existing monitor
    [self stopMonitoringDirectory];

    int fd = open(path.fileSystemRepresentation, O_EVTONLY);
    if (fd < 0) {
        NSLog(@"Unable to open path for monitoring: %s", path.fileSystemRepresentation);
        self.monitoredDirectoryFD = -1;
        return;
    }
    self.monitoredDirectoryFD = fd;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    unsigned long mask = DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_REVOKE;
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd, mask, queue);
    if (!src) {
        close(fd);
        self.monitoredDirectoryFD = -1;
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(src, ^{
        unsigned long flags = dispatch_source_get_data(src);
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf loadFilesAndFolders];

            // If the directory itself was deleted/moved, restart monitoring after a short delay
            if (flags & (DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE)) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf stopMonitoringDirectory];
                    [weakSelf startMonitoringDirectoryAtPath:path];
                });
            }
        });
    });

    dispatch_source_set_cancel_handler(src, ^{
        close(fd);
    });

    self.directoryMonitor = src;
    dispatch_resume(src);
}

- (void)stopMonitoringDirectory {
    if (self.directoryMonitor) {
        dispatch_source_cancel(self.directoryMonitor);
        self.directoryMonitor = nil;
    } else if (self.monitoredDirectoryFD > 0) {
        close(self.monitoredDirectoryFD);
        self.monitoredDirectoryFD = -1;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startMonitoringDirectoryAtPath:self.currentPath];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopMonitoringDirectory];
}

- (void)dealloc {
    [self stopMonitoringDirectory];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SettingsChanged" object:nil];
}

// --- MÉTODO REFACTORIZADO PARA ABRIR ARCHIVOS Y CARPETAS ---
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedItemName = self.isSearching ? self.filteredContents[indexPath.row] : self.contents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:selectedItemName];

    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];

    @try {
        if (isDirectory) {
            FileBrowserViewController *newBrowser = [[FileBrowserViewController alloc] init];
            newBrowser.currentPath = fullPath;
            [self.navigationController pushViewController:newBrowser animated:YES];
        } else if ([fullPath.pathExtension.lowercaseString isEqualToString:@"zip"]) {
            [self extractZipAtPath:fullPath toDestination:self.currentPath];
        } else if ([self isImageFile:fullPath] || [self isVideoFile:fullPath] || [self isAudioFile:fullPath]) {
            [self showQuickLookForFile:fullPath];
        } else if ([self isFontFile:fullPath]) {
            [self openFontViewerForFile:fullPath];
        } else if ([self isSQLiteFile:fullPath]) {
            [self openSQLiteViewerForFile:fullPath];
        } else if ([fullPath.pathExtension.lowercaseString isEqualToString:@"plist"]) {
            [self openPlistEditorForFile:fullPath];
        } else if ([self isTextFile:fullPath]) {
            [self openTextEditorForFile:fullPath];
        } else {
            UIAlertController *noViewerAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sin visor", nil) message:NSLocalizedString(@"No hay un visor disponible para este tipo de archivo.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [noViewerAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Abrir como texto", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self openTextEditorForFile:fullPath];
            }]];
            [noViewerAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:noViewerAlert animated:YES completion:nil];
        }
    } @catch (NSException *exception) {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"No se pudo abrir el archivo: %@", nil), exception.reason] preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// Helpers para abrir visores específicos
- (void)openFontViewerForFile:(NSString *)filePath {
    FontViewerViewController *fontViewer = [[FontViewerViewController alloc] init];
    fontViewer.fontPath = filePath;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:fontViewer];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)openSQLiteViewerForFile:(NSString *)filePath {
    SQLiteViewerViewController *sqliteViewer = [[SQLiteViewerViewController alloc] init];
    sqliteViewer.dbPath = filePath;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:sqliteViewer];
    [self presentViewController:navController animated:YES completion:nil];
}


#pragma mark - Context Menu (iOS 13+)

// Menú contextual moderno estilo iOS
- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    NSString *itemName = self.isSearching ? self.filteredContents[indexPath.row] : self.contents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:itemName];
    
    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:^UIViewController * _Nullable{
        // Vista previa para archivos compatibles
        return [self previewViewControllerForPath:fullPath];
    }
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [self contextMenuForItemAtPath:fullPath itemName:itemName];
    }];
}

// Crear el menú contextual con todas las acciones
- (UIMenu *)contextMenuForItemAtPath:(NSString *)fullPath itemName:(NSString *)itemName API_AVAILABLE(ios(13.0)) {
    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    NSMutableArray *actions = [NSMutableArray array];
    
    // Acción de Vista Rápida
    if (!isDirectory) {
        UIAction *quickLookAction = [UIAction actionWithTitle:NSLocalizedString(@"Vista Rápida", nil)
                                                        image:[UIImage systemImageNamed:@"eye"]
                                                   identifier:nil
                                                      handler:^(__kindof UIAction * _Nonnull action) {
            [self showQuickLookForFile:fullPath];
        }];
        [actions addObject:quickLookAction];
    }
    
    // Acción de Copiar
    UIAction *copyAction = [UIAction actionWithTitle:NSLocalizedString(@"Copiar", nil)
                                               image:[UIImage systemImageNamed:@"doc.on.doc"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = fullPath;
        pendingOperation = @"copy";
    }];
    [actions addObject:copyAction];
    
    // Acción de Mover
    UIAction *moveAction = [UIAction actionWithTitle:NSLocalizedString(@"Mover", nil)
                                               image:[UIImage systemImageNamed:@"folder"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = fullPath;
        pendingOperation = @"move";
    }];
    [actions addObject:moveAction];
    
    // Acción de Renombrar
    UIAction *renameAction = [UIAction actionWithTitle:NSLocalizedString(@"Renombrar", nil)
                                                 image:[UIImage systemImageNamed:@"pencil"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        [self renameItemAtPath:fullPath];
    }];
    [actions addObject:renameAction];
    
    // Acción de Comprimir
    UIAction *compressAction = [UIAction actionWithTitle:NSLocalizedString(@"Comprimir", nil)
                                                   image:[UIImage systemImageNamed:@"archivebox"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
        [self compressItemAtPath:fullPath itemName:itemName isDirectory:isDirectory];
    }];
    [actions addObject:compressAction];
    
    // Submenú "Ver como" para archivos
    if (!isDirectory) {
        NSMutableArray *viewAsActions = [NSMutableArray array];
        
        UIAction *viewAsTextAction = [UIAction actionWithTitle:NSLocalizedString(@"Texto", nil)
                                                         image:[UIImage systemImageNamed:@"doc.text"]
                                                    identifier:nil
                                                       handler:^(__kindof UIAction * _Nonnull action) {
            [self openTextEditorForFile:fullPath];
        }];
        [viewAsActions addObject:viewAsTextAction];

        // Add plist editor option if it's a plist file
        if ([fullPath.pathExtension.lowercaseString isEqualToString:@"plist"]) {
            UIAction *viewAsPlistAction = [UIAction actionWithTitle:NSLocalizedString(@"Plist Editor", nil)
                                                              image:[UIImage systemImageNamed:@"list.bullet"]
                                                         identifier:nil
                                                            handler:^(__kindof UIAction * _Nonnull action) {
                [self openPlistEditorForFile:fullPath];
            }];
            [viewAsActions addObject:viewAsPlistAction];
        }
        
        // Opción 'Hexadecimal' eliminada (visor removido)

        
        UIAction *viewAsPropertiesAction = [UIAction actionWithTitle:NSLocalizedString(@"Propiedades", nil)
                                                               image:[UIImage systemImageNamed:@"info.circle"]
                                                          identifier:nil
                                                             handler:^(__kindof UIAction * _Nonnull action) {
            FilePropertiesViewController *propertiesVC = [[FilePropertiesViewController alloc] init];
            propertiesVC.filePath = fullPath;
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:propertiesVC];
            [self presentViewController:navController animated:YES completion:nil];
        }];
        [viewAsActions addObject:viewAsPropertiesAction];
        
        UIMenu *viewAsMenu = [UIMenu menuWithTitle:NSLocalizedString(@"Ver como", nil)
                                             image:[UIImage systemImageNamed:@"eye.circle"]
                                        identifier:nil
                                           options:0
                                          children:viewAsActions];
        [actions addObject:viewAsMenu];
    }
    
    // Acción de Extraer (solo para ZIP)
    if (!isDirectory && [fullPath.pathExtension.lowercaseString isEqualToString:@"zip"]) {
        UIAction *extractAction = [UIAction actionWithTitle:NSLocalizedString(@"Extraer", nil)
                                                      image:[UIImage systemImageNamed:@"arrow.up.doc"]
                                                 identifier:nil
                                                    handler:^(__kindof UIAction * _Nonnull action) {
            [self extractZipAtPath:fullPath toDestination:self.currentPath];
        }];
        [actions addObject:extractAction];
    }
    
    // Acción de Hacer Escribible (solo para directorios no escribibles)
    if (isDirectory && ![[NSFileManager defaultManager] isWritableFileAtPath:fullPath]) {
        UIAction *makeWritableAction = [UIAction actionWithTitle:NSLocalizedString(@"Hacer Escribible", nil)
                                                           image:[UIImage systemImageNamed:@"lock.open"]
                                                      identifier:nil
                                                         handler:^(__kindof UIAction * _Nonnull action) {
            [self makeDirectoryWritable:fullPath];
        }];
        [actions addObject:makeWritableAction];
    }
    
    // Acción de Ver Información
    UIAction *infoAction = [UIAction actionWithTitle:NSLocalizedString(@"Ver Información", nil)
                                               image:[UIImage systemImageNamed:@"info.circle"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
        FilePropertiesViewController *propertiesVC = [[FilePropertiesViewController alloc] init];
        propertiesVC.filePath = fullPath;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:propertiesVC];
        [self presentViewController:navController animated:YES completion:nil];
    }];
    [actions addObject:infoAction];
    
    // Acción de Eliminar (destructiva)
    UIAction *deleteAction = [UIAction actionWithTitle:NSLocalizedString(@"Eliminar", nil)
                                                 image:[UIImage systemImageNamed:@"trash"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        [self deleteItemAtPath:fullPath];
    }];
    deleteAction.attributes = UIMenuElementAttributesDestructive;
    [actions addObject:deleteAction];
    
    return [UIMenu menuWithTitle:NSLocalizedString(@"Menú contextual", nil) children:actions];
}

// Vista previa para Quick Look
- (UIViewController *)previewViewControllerForPath:(NSString *)filePath API_AVAILABLE(ios(13.0)) {
    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    if (isDirectory) {
        return nil;
    }
    
    // Para imágenes, mostrar vista previa de imagen
    if ([self isImageFile:filePath]) {
        ImageViewerViewController *imageViewer = [[ImageViewerViewController alloc] init];
        imageViewer.imagePath = filePath;
        return imageViewer;
    }
    
    return nil;
}

#pragma mark - Swipe Actions (iOS 11+)

// Swipe actions para eliminar (deslizar desde la derecha)
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    NSString *itemName = self.isSearching ? self.filteredContents[indexPath.row] : self.contents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:itemName];
    
    // Acción de eliminar
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"Eliminar", nil)
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self deleteItemAtPath:fullPath];
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage systemImageNamed:@"trash"];
    deleteAction.backgroundColor = [UIColor systemRedColor];
    
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    return configuration;
}

// Swipe actions para compartir/información (deslizar desde la izquierda)
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    NSString *itemName = self.isSearching ? self.filteredContents[indexPath.row] : self.contents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:itemName];
    
    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    // Acción de información
    UIContextualAction *infoAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:NSLocalizedString(@"Info", nil)
                                                                           handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        FilePropertiesViewController *propertiesVC = [[FilePropertiesViewController alloc] init];
        propertiesVC.filePath = fullPath;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:propertiesVC];
        [self presentViewController:navController animated:YES completion:nil];
        completionHandler(YES);
    }];
    infoAction.image = [UIImage systemImageNamed:@"info.circle"];
    infoAction.backgroundColor = [UIColor systemBlueColor];
    
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[infoAction]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

#pragma mark - Helper Methods for Context Menu Actions

// Mostrar Quick Look para un archivo
- (void)showQuickLookForFile:(NSString *)filePath {
    self.previewFilePath = filePath;
    QLPreviewController *previewController = [[QLPreviewController alloc] init];
    previewController.dataSource = self;
    previewController.delegate = self;
    [self presentViewController:previewController animated:YES completion:nil];
}

// Comprimir archivo o carpeta
- (void)compressItemAtPath:(NSString *)fullPath itemName:(NSString *)itemName isDirectory:(BOOL)isDirectory {
    NSString *zipPath = [self.currentPath stringByAppendingPathComponent:[itemName stringByAppendingString:@".zip"]];
    BOOL success;
    if (isDirectory) {
        success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:fullPath];
    } else {
        success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:@[fullPath]];
    }
    if (success) {
        [self loadFilesAndFolders];
    } else {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo comprimir", nil) preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
}

// Abrir editor de texto
- (void)openTextEditorForFile:(NSString *)filePath {
    TextEditorViewController *editor = [[TextEditorViewController alloc] init];
    editor.filePath = filePath;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editor];
    [self presentViewController:navController animated:YES completion:nil];
}

// Abrir visor hexadecimal (deshabilitado)
- (void)openHexViewerForFile:(NSString *)filePath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sin visor hexadecimal", nil) message:NSLocalizedString(@"El visor hexadecimal ha sido eliminado.", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
} 

// Abrir editor de plist
- (void)openPlistEditorForFile:(NSString *)filePath {
    PlistEditorViewController *plistEditor = [[PlistEditorViewController alloc] init];
    plistEditor.filePath = filePath;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:plistEditor];
    [self presentViewController:navController animated:YES completion:nil];
}

// Hacer directorio escribible
- (void)makeDirectoryWritable:(NSString *)fullPath {
    NSString *result = [RootHelper setPermissionForPath:fullPath];
    if ([result isEqualToString:@"0"]) {
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Éxito", nil) message:NSLocalizedString(@"Permisos de escritura agregados.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
    } else {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudieron cambiar los permisos. El directorio puede estar protegido por el sistema.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
}

// Aplicar propietario y permisos recursivamente basados en el directorio padre
- (void)applyParentOwnershipAndPermissionsToPath:(NSString *)targetPath parentPath:(NSString *)parentPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSDictionary *parentAttr = [fm attributesOfItemAtPath:parentPath error:&err];
    if (err || !parentAttr) {
        NSLog(@"No se pudieron obtener atributos del directorio padre %@: %@", parentPath, err.localizedDescription);
        return;
    }

    NSString *owner = parentAttr[NSFileOwnerAccountName];
    NSString *group = parentAttr[NSFileGroupOwnerAccountName];
    NSNumber *perm = parentAttr[NSFilePosixPermissions];
    unsigned int mode = (perm ? [perm unsignedIntValue] : 0) & 07777;
    NSString *permStr = [NSString stringWithFormat:@"%o", mode];

    // Si no hay owner/group como nombre, intentar resolver desde uid/gid
    if (!owner || !group) {
        struct stat pst;
        if (stat(parentPath.UTF8String, &pst) == 0) {
            struct passwd *pw = getpwuid(pst.st_uid);
            if (pw) owner = [NSString stringWithUTF8String:pw->pw_name];
            struct group *gr = getgrgid(pst.st_gid);
            if (gr) group = [NSString stringWithUTF8String:gr->gr_name];
        }
    }

    // Aplicar a la carpeta raíz
    if (owner) [RootHelper changeOwnerOf:targetPath to:owner];
    if (group) [RootHelper changeGroupOf:targetPath to:group];
    if (permStr) [RootHelper changePermissionsOf:targetPath to:permStr];

    // Recorrer recursivamente y aplicar a cada elemento
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:targetPath];
    NSString *relative;
    while ((relative = [enumerator nextObject])) {
        NSString *full = [targetPath stringByAppendingPathComponent:relative];
        BOOL isDir = NO;
        [fm fileExistsAtPath:full isDirectory:&isDir];

        if (owner) [RootHelper changeOwnerOf:full to:owner];
        if (group) [RootHelper changeGroupOf:full to:group];

        // Ajustar permisos: si es directorio, asegurarse de que tenga bit de ejecución
        unsigned int finalMode = mode;
        if (isDir) finalMode |= (S_IXUSR | S_IXGRP | S_IXOTH);
        else finalMode &= ~(S_IXUSR | S_IXGRP | S_IXOTH);
        NSString *finalPermStr = [NSString stringWithFormat:@"%o", finalMode];
        [RootHelper changePermissionsOf:full to:finalPermStr];
    }
}

// Eliminar archivo o carpeta
- (void)deleteItemAtPath:(NSString *)fullPath {
    // Pedir confirmación antes de eliminar
    NSString *itemName = [fullPath lastPathComponent];
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Eliminar", nil) message:[NSString stringWithFormat:NSLocalizedString(@"¿Deseas eliminar '%@'?", nil), itemName] preferredStyle:UIAlertControllerStyleAlert];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
    [confirmAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Eliminar", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        SettingsManager *mgr = [SettingsManager sharedManager];
        NSString *result;
        if ([mgr useTrash]) {
            result = [RootHelper trashItemAt:fullPath];
        } else {
            result = [RootHelper removeItemAt:fullPath];
        }
        if ([result isEqualToString:@"0"]) {
            [self loadFilesAndFolders];
        } else {
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo eliminar.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:errorAlert animated:YES completion:nil];
        }
    }]];
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

#pragma mark - QLPreviewControllerDataSource

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [NSURL fileURLWithPath:self.previewFilePath];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isSearching ? self.filteredContents.count : self.contents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"FileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    NSString *itemName = self.isSearching ? self.filteredContents[indexPath.row] : self.contents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:itemName];
    
    cell.textLabel.text = itemName;
    cell.textLabel.font = [Typography bodyMedium];
    
    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    // Obtener información del archivo para el subtítulo
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:&error];
    if (!error && attributes) {
        if (isDirectory) {
            // Para carpetas, mostrar número de elementos
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fullPath error:nil];
            NSInteger itemCount = contents.count;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld elemento%@", (long)itemCount, itemCount == 1 ? @"" : @"s"];
        } else {
            // Para archivos, mostrar tamaño y fecha
            NSString *size = [NSByteCountFormatter stringFromByteCount:[attributes[NSFileSize] unsignedLongLongValue] countStyle:NSByteCountFormatterCountStyleFile];
            NSDate *modDate = attributes[NSFileModificationDate];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateStyle = NSDateFormatterShortStyle;
            formatter.timeStyle = NSDateFormatterShortStyle;
            NSString *dateString = [formatter stringFromDate:modDate];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", size, dateString];
        }
        cell.detailTextLabel.font = [Typography labelSmall];
        if (@available(iOS 13.0, *)) {
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            cell.detailTextLabel.textColor = [UIColor grayColor];
        }
    }
    
    if (isDirectory) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        // Color para icono de carpeta (usa color del sistema y fallback para iOS < 13)
        UIColor *folderColor;
        if (@available(iOS 13.0, *)) {
            // Usar azul del sistema para coincidir con el icono proporcionado
            folderColor = [UIColor systemBlueColor];
        } else {
            folderColor = [UIColor blueColor];
        }

        // Intentar varias formas de cargar el asset: primero imageNamed (escala automática), luego ruta explícita
        UIImage *folderImage = [UIImage imageNamed:@"folder"];
        if (!folderImage) folderImage = [UIImage imageNamed:@"Icons/folder"];
        if (!folderImage) {
            NSString *folderPath = [[NSBundle mainBundle] pathForResource:@"folder" ofType:@"png" inDirectory:@"Icons"];
            if (folderPath) folderImage = [UIImage imageWithContentsOfFile:folderPath];
        }

        if (folderImage) {
            NSLog(@"[FileBrowser] Loaded folder image (w=%.0f h=%.0f scale=%.1f)", folderImage.size.width, folderImage.size.height, folderImage.scale);
            UIImage *resized = [self resizeImage:folderImage toSize:CGSizeMake(28, 28)];
            // Use original rendering so the asset's colors (outline + fill) are preserved
            cell.imageView.image = [resized imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        } else {
            NSLog(@"[FileBrowser] Folder image not found, using fallback SF Symbol");
            if (@available(iOS 13.0, *)) {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
                UIImage *img = [UIImage systemImageNamed:@"folder.fill" withConfiguration:config];
                cell.imageView.image = [img imageWithTintColor:folderColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            } else {
                UIImage *img = [UIImage systemImageNamed:@"folder"];
                if (img) {
                    cell.imageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                    cell.imageView.tintColor = folderColor;
                } else {
                    // Ultimate visual fallback: colored square so user can see placeholder
                    UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), NO, 0.0);
                    [folderColor setFill];
                    UIRectFill(CGRectMake(0, 0, 28, 28));
                    UIImage *box = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    cell.imageView.image = box;
                    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
                }
            }
        }
        [cell setNeedsLayout];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        NSString *extension = [itemName pathExtension].lowercaseString;
        NSString *iconName = extension.length > 0 ? [NSString stringWithFormat:@"Icons/icon/%@", extension] : @"Icons/icon/file";
        UIImage *fileImage = [UIImage imageNamed:iconName];
        if (fileImage) {
            cell.imageView.image = [self resizeImage:fileImage toSize:CGSizeMake(24, 24)];
        } else {
            // Primero intentar un icono genérico 'file.png' incluido en los assets
            UIImage *genericFileImage = [UIImage imageNamed:@"Icons/icon/file"];
            if (genericFileImage) {
                cell.imageView.image = [self resizeImage:genericFileImage toSize:CGSizeMake(24, 24)];
            } else {
                // Usar SF Symbol mapeado según extensión como fallback si no hay asset
                UIImage *symbolImage = [self symbolImageForFileAtPath:fullPath pointSize:20.0];
                if (symbolImage) {
                    cell.imageView.image = symbolImage;
                    cell.imageView.tintColor = [UIColor systemGrayColor];
                    cell.imageView.image = [cell.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                } else {
                    if (@available(iOS 13.0, *)) {
                        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
                        cell.imageView.image = [[UIImage systemImageNamed:@"doc.fill" withConfiguration:config] imageWithTintColor:[UIColor systemGrayColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                    } else {
                        cell.imageView.image = [UIImage systemImageNamed:@"doc"];
                    }
                }
            }
        }
    }
    
    // Estilo: fondo negro puro para OLED y rendimiento
    cell.backgroundColor = [UIColor blackColor]; // Fondo negro puro para OLED
    cell.textLabel.textColor = [UIColor whiteColor];
    if (cell.detailTextLabel) cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    cell.contentView.opaque = YES; // Esto mejora mucho el rendimiento del scroll
    
    return cell;
}

// Altura de celda mejorada para mostrar subtítulo
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

#pragma mark - UITableViewDataSource (Editing)

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Nos aseguramos de que la acción sea una eliminación
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        // 1. Obtener la ruta completa del archivo a eliminar
        NSString *itemName = self.isSearching ? self.filteredContents[indexPath.row] : self.contents[indexPath.row];
        NSString *fullPath = [self.currentPath stringByAppendingPathComponent:itemName];
        
        // 2. Usar RootHelper para eliminar el archivo del disco
        NSString *result = [RootHelper removeItemAt:fullPath];
        
        if ([result isEqualToString:@"0"]) {
            // 4. Si se elimina correctamente:
            //    a. Actualizar nuestro array de datos (el "modelo")
            [self loadFilesAndFolders];
        } else {
            // 3. Si hay un error, mostrar una alerta al usuario
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No se pudo eliminar el archivo.", nil) preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (BOOL)isImageFile:(NSString *)filePath {
    NSString *extension = [filePath.pathExtension lowercaseString];
    NSArray *imageExtensions = @[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tiff", @"tif", @"webp"];
    return [imageExtensions containsObject:extension];
}

- (BOOL)isTextFile:(NSString *)filePath {
    NSString *extension = [filePath.pathExtension lowercaseString];
    NSArray *textExtensions = @[@"txt", @"md", @"json", @"xml", @"html", @"css", @"js", @"py", @"c", @"cpp", @"h", @"m", @"plist"];
    if ([textExtensions containsObject:extension]) {
        return YES;
    }
    // Try to read as UTF-8 to check if it's text
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    return content != nil && error == nil;
}

- (BOOL)isFontFile:(NSString *)filePath {
    NSString *extension = [filePath.pathExtension lowercaseString];
    return [extension isEqualToString:@"ttf"] || [extension isEqualToString:@"otf"];
}

- (BOOL)isSQLiteFile:(NSString *)filePath {
    NSString *extension = [filePath.pathExtension lowercaseString];
    return [extension isEqualToString:@"sqlite"] || [extension isEqualToString:@"db"];
}

- (BOOL)isVideoFile:(NSString *)filePath {
    NSString *extension = [filePath.pathExtension lowercaseString];
    NSArray *videoExtensions = @[@"mp4", @"mov", @"avi", @"mkv", @"wmv", @"flv", @"webm", @"m4v"];
    return [videoExtensions containsObject:extension];
}

- (BOOL)isAudioFile:(NSString *)filePath {
    NSString *extension = [filePath.pathExtension lowercaseString];
    NSArray *audioExtensions = @[@"mp3", @"wav", @"aac", @"flac", @"ogg", @"m4a", @"wma"];
    return [audioExtensions containsObject:extension];
}

- (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

// Map file extensions to SF Symbols (returns a configured UIImage when available)
- (UIImage *)symbolImageForFileAtPath:(NSString *)fullPath pointSize:(CGFloat)pointSize {
    BOOL isDirectory = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
    if (isDirectory) return nil;

    NSString *ext = [fullPath.pathExtension lowercaseString];
    NSDictionary *map = @{
        @"zip": @"archivebox",
        @"tar": @"archivebox",
        @"gz": @"archivebox",
        @"png": @"photo",
        @"jpg": @"photo",
        @"jpeg": @"photo",
        @"gif": @"photo",
        @"webp": @"photo",
        @"mp4": @"film",
        @"mov": @"film",
        @"mkv": @"film",
        @"mp3": @"music.note",
        @"wav": @"music.note",
        @"flac": @"music.note",
        @"pdf": @"doc.richtext",
        @"txt": @"doc.plaintext",
        @"md": @"doc.plaintext",
        @"plist": @"doc.plaintext",
        @"sqlite": @"cylinder",
        @"db": @"cylinder",
        @"ttf": @"textformat",
        @"otf": @"textformat",
        @"html": @"chevron.left.forwardslash.chevron.right",
        @"css": @"paintbrush",
        @"js": @"curlybraces",
        @"json": @"curlybraces",
        @"ipa": @"app",
        @"app": @"app",
    };

    NSString *symbolName = map[ext];

    // If there's no mapped SF Symbol, or the system image isn't available, fall back to a bundled "file.png" icon
    if (!symbolName) {
        UIImage *img = [UIImage imageNamed:@"file"];
        if (!img) {
            NSString *path = [[NSBundle mainBundle] pathForResource:@"file" ofType:@"png"];
            if (path) img = [UIImage imageWithContentsOfFile:path];
        }
        if (img) {
            UIImage *resized = [self resizeImage:img toSize:CGSizeMake(pointSize, pointSize)];
            return resized;
        }
        return nil;
    }

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightRegular];
        UIImage *img = [UIImage systemImageNamed:symbolName];
        if (!img) {
            // fallback to bundled icon if SF Symbol not available
            UIImage *fallback = [UIImage imageNamed:@"file"];
            if (!fallback) {
                NSString *path = [[NSBundle mainBundle] pathForResource:@"file" ofType:@"png"];
                if (path) fallback = [UIImage imageWithContentsOfFile:path];
            }
            if (fallback) return [self resizeImage:fallback toSize:CGSizeMake(pointSize, pointSize)];
            return nil;
        }
        return [img imageWithConfiguration:config];
    }
    return nil;
}

- (void)showViewAsMenuForFile:(NSString *)filePath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Ver como", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    // Propiedades
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Propiedades", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        FilePropertiesViewController *propertiesVC = [[FilePropertiesViewController alloc] init];
        propertiesVC.filePath = filePath;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:propertiesVC];
        [self presentViewController:navController animated:YES completion:nil];
    }]];

    // Texto
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Texto", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        TextEditorViewController *editor = [[TextEditorViewController alloc] init];
        editor.filePath = filePath;
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editor];
        [self presentViewController:navController animated:YES completion:nil];
    }]];

    // Hexadecimal eliminado: ofrecer abrir como texto
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Hexadecimal", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *noViewerAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sin visor hexadecimal", nil) message:NSLocalizedString(@"El visor hexadecimal ha sido eliminado. ¿Abrir como texto?", nil) preferredStyle:UIAlertControllerStyleAlert];
        [noViewerAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Abrir como texto", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            TextEditorViewController *editor = [[TextEditorViewController alloc] init];
            editor.filePath = filePath;
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:editor];
            [self presentViewController:navController animated:YES completion:nil];
        }]];
        [noViewerAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:noViewerAlert animated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFileProperties:(NSString *)filePath {
    FilePropertiesViewController *propertiesVC = [[FilePropertiesViewController alloc] init];
    propertiesVC.filePath = filePath;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:propertiesVC];
    [self presentViewController:navController animated:YES completion:nil];
}


@end
