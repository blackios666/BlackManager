#import "blackRootViewController.h"
#import "FileBrowserViewController.h"
#import "AppListViewController.h"
#import "CreditsViewController.h"
#import "Typography.h"
#import "SettingsViewController.h"

@implementation blackRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // --- Pestaña 1: Explorador de Archivos (Raíz) ---
    FileBrowserViewController *rootFileBrowser = [[FileBrowserViewController alloc] init];
    rootFileBrowser.currentPath = @"/var/mobile/Documents/";
    UINavigationController *filesNavController = [[UINavigationController alloc] initWithRootViewController:rootFileBrowser];
    filesNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Archivos", nil) image:[UIImage systemImageNamed:@"folder"] tag:0];
    
    // --- Pestaña 2: Lista de Aplicaciones ---
    AppListViewController *appListVC = [[AppListViewController alloc] init];
    UINavigationController *appsNavController = [[UINavigationController alloc] initWithRootViewController:appListVC];
    
    // --- AQUÍ SE CONFIGURA EL ÍCONO ---
    // El ícono actual es "app.grid". Puedes cambiarlo por otro de SF Symbols.
    // Por ejemplo, prueba con "square.grid.3x3" o "apps.iphone".
    appsNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Apps", nil) image:[UIImage systemImageNamed:@"square.grid.3x3"] tag:0];

    // --- Pestaña 3: Créditos ---
    CreditsViewController *creditsVC = [[CreditsViewController alloc] init];
    UINavigationController *creditsNavController = [[UINavigationController alloc] initWithRootViewController:creditsVC];
    creditsNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Créditos", nil) image:[UIImage systemImageNamed:@"person.circle"] tag:0];

    // --- Pestaña 4: Ajustes ---
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Ajustes", nil) image:[UIImage systemImageNamed:@"gearshape"] tag:0];

    // Asignar las pestañas
    self.viewControllers = @[filesNavController, appsNavController, creditsNavController, settingsNavController];

    // Aplicar títulos localizados a las pestañas
    [self updateLocalizedTitles];

    // Escuchar cambios de idioma para actualizar UI en caliente
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageChanged:) name:@"LanguageChanged" object:nil];
}

- (void)updateLocalizedTitles {
    if (self.viewControllers.count >= 4) {
        UIViewController *filesNav = self.viewControllers[0];
        UIViewController *appsNav = self.viewControllers[1];
        UIViewController *creditsNav = self.viewControllers[2];
        UIViewController *settingsNav = self.viewControllers[3];

        filesNav.tabBarItem.title = NSLocalizedString(@"Archivos", nil);
        appsNav.tabBarItem.title = NSLocalizedString(@"Apps", nil);
        creditsNav.tabBarItem.title = NSLocalizedString(@"Créditos", nil);
        settingsNav.tabBarItem.title = NSLocalizedString(@"Ajustes", nil);
    }
}

- (void)languageChanged:(NSNotification *)note {
    [self updateLocalizedTitles];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"LanguageChanged" object:nil];
}



@end