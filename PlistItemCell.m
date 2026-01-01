#import "PlistItemCell.h"
#import "Typography.h"

#define STRING_COLOR [UIColor systemBlueColor]
#define BOOLEAN_COLOR [UIColor systemGreenColor]
#define NUMBER_COLOR [UIColor systemGreenColor]
#define DICTIONARY_COLOR [UIColor systemPurpleColor]
#define ARRAY_COLOR [UIColor systemTealColor]
#define DATE_COLOR [UIColor systemRedColor]
#define DATA_COLOR [UIColor systemGrayColor]
#define UNKNOWN_COLOR [UIColor systemGrayColor]

@implementation PlistItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
        [self setupConstraints];
    }
    return self;
}

- (void)setupViews {
    self.typeIconView = [[UIImageView alloc] init];
    self.typeIconView.tintColor = [UIColor systemBlueColor];
    self.typeIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.typeIconView];

    self.typeIndicatorView = [[UIView alloc] init];
    self.typeIndicatorView.layer.cornerRadius = 6;
    self.typeIndicatorView.clipsToBounds = YES;
    [self.contentView addSubview:self.typeIndicatorView];

    self.keyLabel = [[UILabel alloc] init];
    self.keyLabel.font = [Typography bodyMedium];
    self.keyLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.keyLabel];

    self.typeLabel = [[UILabel alloc] init];
    self.typeLabel.font = [Typography labelSmall];
    self.typeLabel.textColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:self.typeLabel];

    self.valuePreviewLabel = [[UILabel alloc] init];
    self.valuePreviewLabel.font = [Typography labelSmall];
    self.valuePreviewLabel.textColor = [UIColor tertiaryLabelColor];
    self.valuePreviewLabel.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.valuePreviewLabel];

    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)setupConstraints {
    self.typeIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.valuePreviewLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        // Type icon
        [self.typeIconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.typeIconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.typeIconView.widthAnchor constraintEqualToConstant:24],
        [self.typeIconView.heightAnchor constraintEqualToConstant:24],

        // Type indicator
        [self.typeIndicatorView.leadingAnchor constraintEqualToAnchor:self.typeIconView.trailingAnchor constant:12],
        [self.typeIndicatorView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.typeIndicatorView.widthAnchor constraintEqualToConstant:12],
        [self.typeIndicatorView.heightAnchor constraintEqualToConstant:12],

        // Key label
        [self.keyLabel.leadingAnchor constraintEqualToAnchor:self.typeIndicatorView.trailingAnchor constant:12],
        [self.keyLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.keyLabel.trailingAnchor constraintEqualToAnchor:self.valuePreviewLabel.leadingAnchor constant:-8],

        // Type label
        [self.typeLabel.leadingAnchor constraintEqualToAnchor:self.keyLabel.leadingAnchor],
        [self.typeLabel.topAnchor constraintEqualToAnchor:self.keyLabel.bottomAnchor constant:2],
        [self.typeLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.typeLabel.trailingAnchor constraintEqualToAnchor:self.keyLabel.trailingAnchor],

        // Value preview
        [self.valuePreviewLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.valuePreviewLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [self.valuePreviewLabel.widthAnchor constraintEqualToConstant:120]
    ]];
}

- (void)configureWithKey:(NSString *)key value:(id)value {
    self.keyLabel.text = key;

    if ([value isKindOfClass:[NSString class]]) {
        self.typeLabel.text = NSLocalizedString(@"Texto", nil);
        self.valuePreviewLabel.text = [NSString stringWithFormat:@"\"%@\"", value];
        self.typeIndicatorView.backgroundColor = STRING_COLOR;
        self.typeIconView.image = [[UIImage systemImageNamed:@"text.quote"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        if (strcmp([value objCType], @encode(BOOL)) == 0) {
            self.typeLabel.text = NSLocalizedString(@"Booleano", nil);
            self.valuePreviewLabel.text = [value boolValue] ? NSLocalizedString(@"true", nil) : NSLocalizedString(@"false", nil);
            self.typeIndicatorView.backgroundColor = BOOLEAN_COLOR;
            self.typeIconView.image = [[UIImage systemImageNamed:@"checkmark.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            self.typeLabel.text = NSLocalizedString(@"Número", nil);
            self.valuePreviewLabel.text = [value stringValue];
            self.typeIndicatorView.backgroundColor = NUMBER_COLOR;
            self.typeIconView.image = [[UIImage systemImageNamed:@"number"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        self.typeLabel.text = NSLocalizedString(@"Diccionario", nil);
        self.valuePreviewLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), (unsigned long)[value count]];
        self.typeIndicatorView.backgroundColor = DICTIONARY_COLOR;
        self.typeIconView.image = [[UIImage systemImageNamed:@"list.bullet"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else if ([value isKindOfClass:[NSArray class]]) {
        self.typeLabel.text = NSLocalizedString(@"Array", nil);
        self.valuePreviewLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu items", nil), (unsigned long)[value count]];
        self.typeIndicatorView.backgroundColor = ARRAY_COLOR;
        self.typeIconView.image = [[UIImage systemImageNamed:@"list.dash"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else if ([value isKindOfClass:[NSDate class]]) {
        self.typeLabel.text = NSLocalizedString(@"Fecha", nil);
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterShortStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        self.valuePreviewLabel.text = [formatter stringFromDate:value];
        self.typeIndicatorView.backgroundColor = DATE_COLOR;
        self.typeIconView.image = [[UIImage systemImageNamed:@"calendar"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else if ([value isKindOfClass:[NSData class]]) {
        self.typeLabel.text = NSLocalizedString(@"Datos", nil);
        self.valuePreviewLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu bytes", nil), (unsigned long)[value length]];
        self.typeIndicatorView.backgroundColor = DATA_COLOR;
        self.typeIconView.image = [[UIImage systemImageNamed:@"doc"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        self.typeLabel.text = NSLocalizedString(@"Desconocido", nil);
        self.valuePreviewLabel.text = [NSString stringWithFormat:@"%@", [value class]];
        self.typeIndicatorView.backgroundColor = UNKNOWN_COLOR;
        self.typeIconView.image = [[UIImage systemImageNamed:@"questionmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
}

@end
