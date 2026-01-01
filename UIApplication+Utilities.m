// UIApplication+Utilities.m

#import "UIApplication+Utilities.h"
#import <Foundation/Foundation.h>

// Declaración de las funciones C killall y exit (ya están en <stdlib.h>, pero se declaran aquí si no se incluye)
extern int killall(const char *procname);
extern void exit(int status);

@implementation UIApplication (Utilities)

- (void)respring {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackGeneratorStyleSoft];
    [feedback impactOccurred];
    
    // Convertir el bloque de animación de Swift
    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 dampingRatio:1.0 animations:^{
        // Obtener las ventanas conectadas
        NSSet<UIScene *> *connectedScenes = self.connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    window.alpha = 0;
                    window.transform = CGAffineTransformMakeScale(0.9, 0.9);
                }
            }
        }
    }];
    
    // Convertir el bloque de finalización de Swift
    [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
        // Ejecutar killall de C
        killall("SpringBoard");
        killall("FrontBoard");
        killall("BackBoard");
        
        // Llamada a la función deprecated
        [self respringDeprecated];
        
        // Ejecutar exit de C
        sleep(2);
        exit(0);
    }];
    
    [animator startAnimation];
}

- (void)exitGracefully {
    // UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    // El equivalente de Objective-C para la acción de "suspender"
    [[UIControl new] sendAction:@selector(suspend) to:self forEvent:nil];
    
    // Programar la salida con un Timer
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        exit(0);
    }];
}

- (BOOL)checkSandbox {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tempPath = @"/var/mobile/balackios_sandbox_check";
    
    // createFile(atPath:contents:attributes:)
    [fileManager createFileAtPath:tempPath contents:nil attributes:nil];
    
    // fileManager.fileExists(atPath: "/var/mobile/geraniumtemp")
    if ([fileManager fileExistsAtPath:tempPath]) {
        NSError *error = nil;
        
        // removeItem(atPath:)
        if (![fileManager removeItemAtPath:tempPath error:&error]) {
            NSLog(@"Failed to remove sandbox check file: %@", error.localizedDescription);
        }
        
        // Retorna NO si pudo crear/eliminar el archivo (no está en sandbox)
        return NO; 
    }
    
    // Retorna YES si NO pudo crear el archivo (está en sandbox)
    return YES;
}

// Método de respring 'deprecated' convertido
// Debe ser declarado en la cabecera para que pueda ser llamado
- (void)respringDeprecated {
    // La implementación original en Swift usa un bucle infinito en C que congela la aplicación
    // La llamada real al método privado respring de Apple no está aquí, pero el código lo emula.
    
    // Este código es el equivalente directo del bucle 'while true' de Swift para forzar el fallo
    // Es una técnica de bug conocida en el desarrollo jailbreak.
    
    UIWindow *window = self.windows.firstObject;
    if (!window) return;
    
    // La implementación exacta en Objective-C puede variar, pero la intención es un bucle infinito:
    while (true) {
        [window snapshotViewAfterScreenUpdates:NO];
    }
}

@end
