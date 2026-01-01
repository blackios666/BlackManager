#import "CreditsViewController.h"

@interface CreditsViewController ()

@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UILabel *youtubeLabel;
@property (nonatomic, strong) UIButton *youtubeButton;
@property (nonatomic, strong) UILabel *telegramLabel;
@property (nonatomic, strong) UIButton *telegramButton;
@property (nonatomic, strong) UILabel *paypalLabel;
@property (nonatomic, strong) UIButton *paypalButton;
@property (nonatomic, strong) UIStackView *stackView;

@end

@implementation CreditsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = NSLocalizedString(@"Créditos", nil);
    
    [self setupUI];
}

- (void)setupUI {
    // Header Label
    self.headerLabel = [[UILabel alloc] init];
    self.headerLabel.text = [NSString stringWithFormat:NSLocalizedString(@"¡Gracias por usar %@!", nil), @"Black iOS"];
    self.headerLabel.font = [UIFont boldSystemFontOfSize:24];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.textColor = [UIColor labelColor];

    // YouTube Label
    self.youtubeLabel = [[UILabel alloc] init];
    self.youtubeLabel.text = NSLocalizedString(@"Suscríbete a mi canal de YouTube para más contenido:", nil);
    self.youtubeLabel.font = [UIFont systemFontOfSize:16];
    self.youtubeLabel.textAlignment = NSTextAlignmentCenter;
    self.youtubeLabel.numberOfLines = 0;
    self.youtubeLabel.textColor = [UIColor secondaryLabelColor];

    // YouTube Button
    self.youtubeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *youtubeConfig = [UIButtonConfiguration filledButtonConfiguration];
    youtubeConfig.title = NSLocalizedString(@"YouTube", nil);
    youtubeConfig.image = [UIImage systemImageNamed:@"play.rectangle"];
    youtubeConfig.imagePlacement = NSDirectionalRectEdgeLeading;
    youtubeConfig.imagePadding = 10;
    youtubeConfig.baseForegroundColor = [UIColor whiteColor];
    youtubeConfig.baseBackgroundColor = [UIColor redColor];
    youtubeConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    self.youtubeButton.configuration = youtubeConfig;
    [self.youtubeButton addTarget:self action:@selector(openYouTube) forControlEvents:UIControlEventTouchUpInside];

    // Telegram Label
    self.telegramLabel = [[UILabel alloc] init];
    self.telegramLabel.text = NSLocalizedString(@"Únete a mi canal de Telegram para actualizaciones:", nil);
    self.telegramLabel.font = [UIFont systemFontOfSize:16];
    self.telegramLabel.textAlignment = NSTextAlignmentCenter;
    self.telegramLabel.numberOfLines = 0;
    self.telegramLabel.textColor = [UIColor secondaryLabelColor];

    // Telegram Button
    self.telegramButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *telegramConfig = [UIButtonConfiguration filledButtonConfiguration];
    telegramConfig.title = NSLocalizedString(@"Telegram", nil);
    telegramConfig.image = [UIImage systemImageNamed:@"paperplane"];
    telegramConfig.imagePlacement = NSDirectionalRectEdgeLeading;
    telegramConfig.imagePadding = 10;
    telegramConfig.baseForegroundColor = [UIColor whiteColor];
    telegramConfig.baseBackgroundColor = [UIColor blueColor];
    telegramConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    self.telegramButton.configuration = telegramConfig;
    [self.telegramButton addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];

    // PayPal Label
    self.paypalLabel = [[UILabel alloc] init];
    self.paypalLabel.text = NSLocalizedString(@"Si te gusta la app, considera donar:", nil);
    self.paypalLabel.font = [UIFont systemFontOfSize:16];
    self.paypalLabel.textAlignment = NSTextAlignmentCenter;
    self.paypalLabel.numberOfLines = 0;
    self.paypalLabel.textColor = [UIColor secondaryLabelColor];

    // PayPal Button
    self.paypalButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *paypalConfig = [UIButtonConfiguration filledButtonConfiguration];
    paypalConfig.title = NSLocalizedString(@"PayPal", nil);
    paypalConfig.image = [UIImage systemImageNamed:@"dollarsign.circle"];
    paypalConfig.imagePlacement = NSDirectionalRectEdgeLeading;
    paypalConfig.imagePadding = 10;
    paypalConfig.baseForegroundColor = [UIColor whiteColor];
    paypalConfig.baseBackgroundColor = [UIColor systemBlueColor];
    paypalConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    self.paypalButton.configuration = paypalConfig;
    [self.paypalButton addTarget:self action:@selector(openPayPal) forControlEvents:UIControlEventTouchUpInside];

    // Stack View
    self.stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.headerLabel,
        self.youtubeLabel,
        self.youtubeButton,
        self.telegramLabel,
        self.telegramButton,
        self.paypalLabel,
        self.paypalButton
    ]];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 20;
    self.stackView.alignment = UIStackViewAlignmentCenter;
    self.stackView.distribution = UIStackViewDistributionEqualSpacing;
    [self.view addSubview:self.stackView];

    // Layout Stack View
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}



- (void)openYouTube {
    NSURL *url = [NSURL URLWithString:@"https://youtube.com/@black_ios26?si=_ZTQHor9vcnnSJR-"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)openTelegram {
    NSURL *url = [NSURL URLWithString:@"https://t.me/black_iOS_YT"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)openPayPal {
    NSURL *url = [NSURL URLWithString:@"https://www.paypal.me/BLACKIOS26"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
