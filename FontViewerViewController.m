#import "FontViewerViewController.h"
#import <CoreText/CoreText.h>
#import "Typography.h"

@interface FontViewerViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIFont *customFont;

@end

@implementation FontViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = [self.fontPath lastPathComponent];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cerrar", nil) style:UIBarButtonItemStylePlain target:self action:@selector(closeViewer)];

    // Load the font
    [self loadFont];

    // Set up scroll view
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    [self setupFontPreview];
}

- (void)closeViewer {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadFont {
    NSData *fontData = [NSData dataWithContentsOfFile:self.fontPath];
    if (!fontData) {
        [self showError:@"No se pudo cargar el archivo de fuente"];
        return;
    }

    CFErrorRef error;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)fontData);
    CGFontRef fontRef = CGFontCreateWithDataProvider(provider);

    if (!fontRef) {
        [self showError:@"No se pudo crear la fuente"];
        return;
    }

    // Check if font is already registered
    NSString *fontName = CFBridgingRelease(CGFontCopyPostScriptName(fontRef));
    if ([UIFont fontWithName:fontName size:17.0]) {
        // Font already registered, use it directly
        self.customFont = [UIFont fontWithName:fontName size:17.0];
        CFRelease(fontRef);
        CFRelease(provider);
        return;
    }

    // Register the font
    CTFontManagerRegisterGraphicsFont(fontRef, &error);
    if (error) {
        [self showError:@"No se pudo registrar la fuente"];
        CFRelease(fontRef);
        CFRelease(provider);
        return;
    }

    self.customFont = [UIFont fontWithName:fontName size:17.0];

    CFRelease(fontRef);
    CFRelease(provider);
}

- (void)setupFontPreview {
    if (!self.customFont) return;

    CGFloat yOffset = 20.0;
    NSArray *sampleTexts = @[
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        @"abcdefghijklmnopqrstuvwxyz",
        @"0123456789",
        @"¡Hola! ¿Cómo estás?",
        @"The quick brown fox jumps over the lazy dog"
    ];

    NSArray *sizes = @[@12.0, @16.0, @20.0, @24.0, @32.0, @48.0];

    for (NSNumber *sizeNum in sizes) {
        CGFloat fontSize = [sizeNum floatValue];

        UILabel *sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, self.view.bounds.size.width - 40, 30)];
        sizeLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Tamaño: %.0f pt", nil), fontSize];
        sizeLabel.font = [Typography labelMedium];
        sizeLabel.textColor = [UIColor secondaryLabelColor];
        [self.scrollView addSubview:sizeLabel];
        yOffset += 35;

        for (NSString *sampleText in sampleTexts) {
            UIFont *sampleFont = [self.customFont fontWithSize:fontSize];
            CGSize textSize = [sampleText sizeWithAttributes:@{NSFontAttributeName: sampleFont}];

            UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, self.view.bounds.size.width - 40, textSize.height + 10)];
            textLabel.text = sampleText;
            textLabel.font = sampleFont;
            textLabel.numberOfLines = 0;
            textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            [self.scrollView addSubview:textLabel];
            yOffset += textSize.height + 15;
        }

        yOffset += 20; // Extra space between size groups
    }

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, yOffset);
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
