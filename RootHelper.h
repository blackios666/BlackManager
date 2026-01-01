// RootHelper.h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Define la clase RootHelper
@interface RootHelper : NSObject

// Propiedad de solo lectura para la ruta del helper
+ (NSString *)rootHelperPath;

// Métodos de manipulación de archivos
+ (NSString *)writeString:(NSString *)str toPath:(NSString *)path;
+ (NSString *)moveFileFrom:(NSString *)sourcePath to:(NSString *)destPath;
+ (NSString *)copyFileFrom:(NSString *)sourcePath to:(NSString *)destPath;
+ (NSString *)createDirectoryAt:(NSString *)path;
  + (NSString *)removeItemAt:(NSString *)path;
  + (NSString *)trashItemAt:(NSString *)path;
  + (NSString *)setPermissionForPath:(NSString *)path;
+ (NSString *)changeOwnerOf:(NSString *)path to:(NSString *)owner;
+ (NSString *)changeGroupOf:(NSString *)path to:(NSString *)group;
+ (NSString *)changePermissionsOf:(NSString *)path to:(NSString *)permissions;
+ (NSString *)changeModificationDateOf:(NSString *)path to:(NSDate *)date;
+ (NSString *)setDaemonPermissionForPath:(NSString *)path;
+ (NSString *)rebuildIconCache;
+ (NSString *)loadMCM; // Este método no usa argumentos en Swift, se mantiene así por consistencia.

@end

NS_ASSUME_NONNULL_END
