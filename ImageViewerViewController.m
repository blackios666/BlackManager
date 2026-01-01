#import "ImageViewerViewController.h"
#import "Typography.h"

@interface ImageViewerViewController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;

@end

@implementation ImageViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // Configurar el scroll view
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 5.0;
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];

    // Configurar la image view
    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollView addSubview:self.imageView];

    // Cargar la imagen
    if (self.imagePath) {
        UIImage *image = [UIImage imageWithContentsOfFile:self.imagePath];
        if (image) {
            self.imageView.image = image;
            [self adjustImageViewSize];
        } else {
            // Mostrar error si no se puede cargar la imagen
            UILabel *errorLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
            errorLabel.text = NSLocalizedString(@"No se pudo cargar la imagen", nil);
            errorLabel.textColor = [UIColor whiteColor];
            errorLabel.textAlignment = NSTextAlignmentCenter;
            [self.view addSubview:errorLabel];
        }
    }

    // Agregar botón de cerrar
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cerrar", nil) style:UIBarButtonItemStylePlain target:self action:@selector(closeViewer)];
    self.navigationItem.leftBarButtonItem = closeButton;

    // Agregar botón de compartir
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareImage)];
    self.navigationItem.rightBarButtonItem = shareButton;
}

- (void)adjustImageViewSize {
    if (self.imageView.image) {
        CGSize imageSize = self.imageView.image.size;
        CGSize viewSize = self.scrollView.bounds.size;

        // Calcular el tamaño para ajustar la imagen al view
        CGFloat scale = MIN(viewSize.width / imageSize.width, viewSize.height / imageSize.height);
        if (scale > 1.0) scale = 1.0; // No agrandar imágenes pequeñas

        CGSize scaledSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
        self.imageView.frame = CGRectMake((viewSize.width - scaledSize.width) / 2, (viewSize.height - scaledSize.height) / 2, scaledSize.width, scaledSize.height);
        self.scrollView.contentSize = scaledSize;
    }
}

- (void)closeViewer {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shareImage {
    if (self.imageView.image) {
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.imageView.image] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    // Centrar la imagen cuando se hace zoom
    UIView *subView = self.imageView;

    CGFloat offsetX = MAX((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0.0);
    CGFloat offsetY = MAX((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0.0);

    subView.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
                                 scrollView.contentSize.height * 0.5 + offsetY);
}

@end
