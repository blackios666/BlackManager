#import "blackAppDelegate.h"
#import "blackRootViewController.h"
#import "SettingsManager.h"
#import "NSBundle+Language.h"

@implementation blackAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Forzar Modo Oscuro (iOS 13+)
    if (@available(iOS 13.0, *)) {
        self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    // --- CORRECCIÓN ---
    // Registrar valores por defecto de ajustes
    [SettingsManager sharedManager];

    // Aplicar idioma seleccionado
    NSString *lang = [[SettingsManager sharedManager] selectedLanguage];
    [NSBundle setLanguage:lang];

    // blackRootViewController ahora es nuestro controlador raíz directamente.
    self.window.rootViewController = [[blackRootViewController alloc] init];

    // Escuchar cambios de configuración para aplicar idioma en caliente
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:@"SettingsChanged" object:nil];

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)settingsChanged:(NSNotification *)note {
    // Reaplicar idioma
    NSString *lang = [[SettingsManager sharedManager] selectedLanguage];
    [NSBundle setLanguage:lang];

    // Reemplazar la raíz con una animación crossfade para forzar refresco completo
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *oldRoot = self.window.rootViewController;
        NSInteger selectedIndex = 0;
        if ([oldRoot isKindOfClass:[UITabBarController class]]) {
            selectedIndex = [(UITabBarController *)oldRoot selectedIndex];
        }

        blackRootViewController *newRoot = [[blackRootViewController alloc] init];
        if ([newRoot isKindOfClass:[UITabBarController class]]) {
            [(UITabBarController *)newRoot setSelectedIndex:selectedIndex];
        }

        [UIView transitionWithView:self.window duration:0.35 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            BOOL oldState = [UIView areAnimationsEnabled];
            self.window.rootViewController = newRoot;
            (void)oldState;
        } completion:^(BOOL finished) {
            // Inform controllers that language changed so they can refresh text immediately
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LanguageChanged" object:lang];
            [self.window makeKeyAndVisible];
        }];
    });
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    // Cuando el usuario selecciona la app en la hoja de compartir, iOS copia el archivo a la carpeta Inbox de la app.
    // Este método maneja el archivo abierto y lo mueve a /var/mobile/Documents/

    NSString *documentsPath = @"/var/mobile/Documents/";
    NSString *fileName = [url lastPathComponent];
    NSString *destinationPath = [documentsPath stringByAppendingPathComponent:fileName];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    // Mover el archivo desde la Inbox a /var/mobile/Documents/
    if ([fileManager moveItemAtPath:[url path] toPath:destinationPath error:&error]) {
        NSLog(@"Archivo movido exitosamente a: %@", destinationPath);
    } else {
        NSLog(@"Error al mover el archivo: %@", error.localizedDescription);
    }

    return YES;
}

@end
