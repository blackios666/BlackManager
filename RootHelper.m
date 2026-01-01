// RootHelper.m

#import "RootHelper.h"
#import "TSUtil.h"

@implementation RootHelper

// Equivalente de static let rootHelperPath
+ (NSString *)rootHelperPath {
    NSString *helperName = @"BlackHelper";
    NSString *path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:helperName];
    // Retorna la ruta o "/" si no se encuentra, como en Swift
    return path ?: @"/";
}

+ (NSString *)executeRootHelperWithArgs:(NSArray<NSString *> *)args {
    NSString *helperPath = [self rootHelperPath];
    
    NSString *stdOut;
    NSString *stdErr;
    int code = spawnRoot(helperPath, args, &stdOut, &stdErr);
    
    // En el código Swift original, retorna el código de estado (status) como un String
    return [NSString stringWithFormat:@"%d", code];
}

#pragma mark - File Operations

+ (NSString *)writeString:(NSString *)str toPath:(NSString *)path {
    return [self executeRootHelperWithArgs:@[@"writedata", str, path]];
}

+ (NSString *)moveFileFrom:(NSString *)sourcePath to:(NSString *)destPath {
    return [self executeRootHelperWithArgs:@[@"filemove", sourcePath, destPath]];
}

+ (NSString *)copyFileFrom:(NSString *)sourcePath to:(NSString *)destPath {
    return [self executeRootHelperWithArgs:@[@"filecopy", sourcePath, destPath]];
}

+ (NSString *)createDirectoryAt:(NSString *)path {
    return [self executeRootHelperWithArgs:@[@"makedirectory", path, @""]];
}

+ (NSString *)removeItemAt:(NSString *)path {
    return [self executeRootHelperWithArgs:@[@"removeitem", path, @""]];
}

+ (NSString *)trashItemAt:(NSString *)path {
    // Trash folder for the app on device
    NSString *trashDir = @"/var/mobile/BlackTrash";
    // Ensure exists
    [self createDirectoryAt:trashDir];
    NSString *base = [path lastPathComponent];
    // Append timestamp to avoid collisions
    NSString *timestamp = [NSString stringWithFormat:@"%llu", (unsigned long long)([[NSDate date] timeIntervalSince1970])];
    NSString *dest = [trashDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", timestamp, base]];
    NSString *moveResult = [self moveFileFrom:path to:dest];
    // Store original path in a .meta file next to the trashed file so we can restore it later
    NSString *metaPath = [dest stringByAppendingString:@".meta"];
    [self writeString:path toPath:metaPath];
    // Make meta readable
    [self changePermissionsOf:metaPath to:@"644"];
    return moveResult;
}

+ (NSString *)setPermissionForPath:(NSString *)path {
    return [self executeRootHelperWithArgs:@[@"permissionset", path, @""]];
}

+ (NSString *)changeOwnerOf:(NSString *)path to:(NSString *)owner {
    return [self executeRootHelperWithArgs:@[@"chown", path, owner]];
}

+ (NSString *)changeGroupOf:(NSString *)path to:(NSString *)group {
    return [self executeRootHelperWithArgs:@[@"chgrp", path, group]];
}

+ (NSString *)changePermissionsOf:(NSString *)path to:(NSString *)permissions {
    return [self executeRootHelperWithArgs:@[@"chmod", path, permissions]];
}

+ (NSString *)changeModificationDateOf:(NSString *)path to:(NSDate *)date {
    NSTimeInterval timestamp = [date timeIntervalSince1970];
    return [self executeRootHelperWithArgs:@[@"setmoddate", path, [NSString stringWithFormat:@"%.0f", timestamp]]];
}

+ (NSString *)setDaemonPermissionForPath:(NSString *)path {
    return [self executeRootHelperWithArgs:@[@"daemonperm", path, @""]];
}

+ (NSString *)rebuildIconCache {
    return [self executeRootHelperWithArgs:@[@"rebuildiconcache", @"", @""]];
}

+ (NSString *)loadMCM {
    return [self executeRootHelperWithArgs:@[@"", @"", @""]];
}

@end
