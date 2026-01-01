#import "TextEditorViewController.h"
#import "Typography.h"

@interface TextEditorViewController () <UITextViewDelegate>
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIBarButtonItem *searchButton;
@property (nonatomic, strong) UIBarButtonItem *fontSizeButton;
@property (nonatomic, strong) UIBarButtonItem *wordWrapButton;
@property (nonatomic, strong) UIBarButtonItem *statsButton;
@end

@implementation TextEditorViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize default values
        self.currentFontSize = 13.0;
        self.wordWrapEnabled = YES;
        self.hasUnsavedChanges = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = [self.filePath lastPathComponent];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Guardar", nil) style:UIBarButtonItemStyleDone target:self action:@selector(save)];

    [self setupStatusBar];
    [self setupTextView];
    [self setupBottomToolbar];
    [self setupConstraints];

    // Load file content
    [self loadFileContent];
}

- (void)setupStatusBar {
    self.statusBar = [[UIView alloc] init];
    self.statusBar.backgroundColor = [UIColor systemGray6Color];
    self.statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusBar];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [Typography labelSmall];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusBar addSubview:self.statusLabel];
}

- (void)setupTextView {
    self.textView = [[UITextView alloc] init];
    self.textView.font = [UIFont monospacedSystemFontOfSize:self.currentFontSize weight:UIFontWeightRegular];
    self.textView.backgroundColor = [UIColor systemBackgroundColor];
    self.textView.textColor = [UIColor labelColor];
    self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textView.delegate = self;
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.textView];
}

- (void)setupBottomToolbar {
    self.bottomToolbar = [[UIToolbar alloc] init];
    self.bottomToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomToolbar];

    // Create toolbar buttons
    self.searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(showSearch)];

    self.fontSizeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"textformat.size"]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(showFontSizeMenu)];

    self.wordWrapButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.left.and.right.text.vertical"]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(toggleWordWrap)];

    self.statsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chart.bar.doc.horizontal"]
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(showStats)];

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];

    [self.bottomToolbar setItems:@[self.searchButton, flexibleSpace, self.fontSizeButton, flexibleSpace, self.wordWrapButton, flexibleSpace, self.statsButton] animated:NO];
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Status bar constraints
        [self.statusBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.statusBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.statusBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.statusBar.heightAnchor constraintEqualToConstant:30],

        // Status label constraints
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusBar.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusBar.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusBar.trailingAnchor constant:-16],

        // Text view constraints
        [self.textView.topAnchor constraintEqualToAnchor:self.statusBar.bottomAnchor],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.bottomToolbar.topAnchor],

        // Bottom toolbar constraints
        [self.bottomToolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.bottomToolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomToolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomToolbar.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)loadFileContent {
    // --- LÓGICA MEJORADA PARA LEER ARCHIVOS ---
    NSError *error = nil;
    NSString *fileExtension = self.filePath.pathExtension.lowercaseString;

    if ([fileExtension isEqualToString:@"plist"]) {
        // Es un Plist: leer como datos y convertir a texto
        NSData *plistData = [NSData dataWithContentsOfFile:self.filePath options:0 error:&error];
        if (plistData) {
            id plistObject = [NSPropertyListSerialization propertyListWithData:plistData options:0 format:NULL error:&error];
            if (plistObject) {
                self.textView.text = [plistObject description]; // Muestra una representación de texto
            }
        }
    } else {
        // Es otro tipo de archivo (ej. .txt): leer como texto plano
        self.textView.text = [NSString stringWithContentsOfFile:self.filePath encoding:NSUTF8StringEncoding error:&error];
    }

    // Si hubo algún error en el proceso, mostrarlo
    if (error) {
        self.textView.text = [NSString stringWithFormat:@"Error al leer el archivo:\n%@", error.localizedDescription];
        self.textView.editable = NO; // No permitir editar si hubo un error de lectura
    } else {
        self.originalText = self.textView.text;
        [self updateStatusBar];
        [self applySyntaxHighlighting];
    }
}

- (void)updateStatusBar {
    NSUInteger lineCount = [self.textView.text componentsSeparatedByString:@"\n"].count;
    NSUInteger wordCount = [self.textView.text componentsSeparatedByString:@" "].count;
    NSUInteger charCount = self.textView.text.length;

    self.statusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Ln %lu, Words %lu, Chars %lu", nil), (unsigned long)lineCount, (unsigned long)wordCount, (unsigned long)charCount];
}

- (void)applySyntaxHighlighting {
    NSString *extension = [self.filePath.pathExtension lowercaseString];

    // Basic syntax highlighting for common file types
    if ([extension isEqualToString:@"json"] || [extension isEqualToString:@"js"]) {
        [self highlightJSON];
    } else if ([extension isEqualToString:@"xml"] || [extension isEqualToString:@"html"]) {
        [self highlightXML];
    } else if ([extension isEqualToString:@"css"]) {
        [self highlightCSS];
    }
    // Add more syntax highlighting as needed
}

- (void)highlightJSON {
    // Basic JSON highlighting - this is a simplified version
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:self.textView.text];

    // Highlight strings (between quotes)
    NSRegularExpression *stringRegex = [NSRegularExpression regularExpressionWithPattern:@"\"[^\"]*\"" options:0 error:nil];
    [stringRegex enumerateMatchesInString:self.textView.text options:0 range:NSMakeRange(0, self.textView.text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemGreenColor] range:result.range];
    }];

    // Highlight numbers
    NSRegularExpression *numberRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\d+\\.?\\d*\\b" options:0 error:nil];
    [numberRegex enumerateMatchesInString:self.textView.text options:0 range:NSMakeRange(0, self.textView.text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:result.range];
    }];

    self.textView.attributedText = attributedText;
}

- (void)highlightXML {
    // Basic XML/HTML highlighting
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:self.textView.text];

    // Highlight tags
    NSRegularExpression *tagRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:0 error:nil];
    [tagRegex enumerateMatchesInString:self.textView.text options:0 range:NSMakeRange(0, self.textView.text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:result.range];
    }];

    // Highlight attributes
    NSRegularExpression *attrRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\w+\\s*=" options:0 error:nil];
    [attrRegex enumerateMatchesInString:self.textView.text options:0 range:NSMakeRange(0, self.textView.text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemOrangeColor] range:result.range];
    }];

    self.textView.attributedText = attributedText;
}

- (void)highlightCSS {
    // Basic CSS highlighting
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:self.textView.text];

    // Highlight selectors
    NSRegularExpression *selectorRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*[^{]+" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [selectorRegex enumerateMatchesInString:self.textView.text options:0 range:NSMakeRange(0, self.textView.text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:result.range];
    }];

    // Highlight properties
    NSRegularExpression *propertyRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b\\w+\\s*:" options:0 error:nil];
    [propertyRegex enumerateMatchesInString:self.textView.text options:0 range:NSMakeRange(0, self.textView.text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [attributedText addAttribute:NSForegroundColorAttributeName value:[UIColor systemGreenColor] range:result.range];
    }];

    self.textView.attributedText = attributedText;
}

#pragma mark - Toolbar Actions

- (void)showSearch {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Buscar y Reemplazar", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Buscar...", nil);
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Reemplazar con...", nil);
    }];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Buscar", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *searchText = alert.textFields[0].text;
        NSString *replaceText = alert.textFields[1].text;
        [self performSearch:searchText replaceWith:replaceText];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performSearch:(NSString *)searchText replaceWith:(NSString *)replaceText {
    if (searchText.length == 0) return;

    NSString *text = self.textView.text;
    if (replaceText.length > 0) {
        // Replace all occurrences
        NSString *newText = [text stringByReplacingOccurrencesOfString:searchText withString:replaceText];
        self.textView.text = newText;
        [self updateStatusBar];
    } else {
        // Just highlight the first occurrence
        NSRange range = [text rangeOfString:searchText];
        if (range.location != NSNotFound) {
            [self.textView scrollRangeToVisible:range];
            [self.textView setSelectedRange:range];
        }
    }
}

- (void)showFontSizeMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Tamaño de Fuente", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *sizes = @[@10, @12, @13, @14, @16, @18, @20, @24];

    for (NSNumber *size in sizes) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@pt", size] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.currentFontSize = [size floatValue];
            self.textView.font = [UIFont monospacedSystemFontOfSize:self.currentFontSize weight:UIFontWeightRegular];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)toggleWordWrap {
    self.wordWrapEnabled = !self.wordWrapEnabled;
    // Note: UITextView doesn't have direct word wrap control, but we can adjust text container
    if (self.wordWrapEnabled) {
        self.textView.textContainer.widthTracksTextView = YES;
        self.textView.textContainer.heightTracksTextView = YES;
    } else {
        self.textView.textContainer.widthTracksTextView = NO;
        self.textView.textContainer.heightTracksTextView = NO;
    }
}

- (void)showStats {
    NSUInteger lineCount = [self.textView.text componentsSeparatedByString:@"\n"].count;
    NSUInteger wordCount = [self.textView.text componentsSeparatedByString:@" "].count;
    NSUInteger charCount = self.textView.text.length;
    NSUInteger charCountNoSpaces = [[self.textView.text stringByReplacingOccurrencesOfString:@" " withString:@""] length];

    NSString *stats = [NSString stringWithFormat:NSLocalizedString(@"Estadísticas del archivo:\n\nLíneas: %lu\nPalabras: %lu\nCaracteres: %lu\nCaracteres (sin espacios): %lu", nil),
                       (unsigned long)lineCount, (unsigned long)wordCount, (unsigned long)charCount, (unsigned long)charCountNoSpaces];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Estadísticas", nil) message:stats preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.hasUnsavedChanges = ![textView.text isEqualToString:self.originalText];
    [self updateStatusBar];
}

#pragma mark - Navigation Actions

- (void)cancel {
    if (self.hasUnsavedChanges) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Cambios sin guardar", nil) message:NSLocalizedString(@"¿Desea descartar los cambios?", nil) preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Descartar", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancelar", nil) style:UIAlertActionStyleCancel handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)save {
    NSError *error = nil;
    NSString *fileExtension = self.filePath.pathExtension.lowercaseString;

    if ([fileExtension isEqualToString:@"plist"]) {
        // Es un Plist: convertir el texto a un objeto y guardarlo
        NSData *data = [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
        id plistObject = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:NULL error:&error];

        if (plistObject && [plistObject respondsToSelector:@selector(writeToFile:atomically:)]) {
            [plistObject writeToFile:self.filePath atomically:YES];
        } else {
            // Si el texto no es un plist válido, muestra un error
            if (!error) { // Crea un error genérico si la serialización no proporcionó uno
                 error = [NSError errorWithDomain:@"com.blackios.Error" code:1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"El formato del texto no es un Plist válido.", nil)}];
            }
        }

    } else {
        // Es otro tipo de archivo: guardar como texto plano
        [self.textView.text writeToFile:self.filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }

    // --- MANEJO DE ERRORES Y CIERRE ---
    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error al Guardar", nil) message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        self.hasUnsavedChanges = NO;
        self.originalText = self.textView.text;
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
