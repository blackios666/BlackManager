#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>

@interface FileBrowserViewController : UITableViewController <UISearchBarDelegate, QLPreviewControllerDataSource, QLPreviewControllerDelegate>

@property (nonatomic, strong) NSString *currentPath;
// Contenido (archivos y carpetas) de la ruta actual
@property (nonatomic, strong) NSArray<NSString *> *contents;
// Contenido filtrado por la búsqueda
@property (nonatomic, strong) NSArray<NSString *> *filteredContents;
// Propiedad opcional para un título personalizado
@property (nonatomic, strong) NSString *customTitle;
// Propiedades para ordenamiento
@property (nonatomic, strong) NSString *sortKey; // "name", "date", "size"
@property (nonatomic, assign) BOOL sortAscending;
// Propiedad para Quick Look
@property (nonatomic, strong) NSString *previewFilePath;

- (void)showFileProperties:(NSString *)filePath;

@end
