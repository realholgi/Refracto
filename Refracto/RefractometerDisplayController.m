//
//  RefractometerDisplayController.m
//  (Sub-)Controller for Display Section in Refractometer Tab
//


#import "RefractometerDisplayController.h"
#import "RefractometerComputation.h"
#import "AppDelegate.h"

#import "NSDecimalNumber+Refracto.h"
#import "UIFont+Monospaced.h"


// Indicators for invalid values in display
#define kInvalidInput  (@"\u2014")
#define kOutOfRangeKey (@"outOfRange")

// Title keys for horizontal mode picker
#define kModeStandardKey      (@"modeStandard")
#define kModeTerrillLinearKey (@"modeTerrillLinear")
#define kModeTerrillCubicKey  (@"modeTerrillCubic")
#define kModeKleierKey        (@"modeKleier")


@interface RefractometerDisplayController ()

@property (weak, nonatomic) IBOutlet UILabel *originalGravity;
@property (weak, nonatomic) IBOutlet UILabel *alcoholByVolume;
@property (weak, nonatomic) IBOutlet UILabel *finalGravity;
@property (weak, nonatomic) IBOutlet UILabel *actualFinalGravity;
@property (weak, nonatomic) IBOutlet UILabel *attenuation;
@property (weak, nonatomic) IBOutlet UILabel *realAttenuation;

@property (weak, nonatomic) IBOutlet HorizontalModePicker *modePicker;

@property (nonatomic) NSDecimalNumber *beforeRefraction;
@property (nonatomic) NSDecimalNumber *currentRefraction;

@end


@implementation RefractometerDisplayController

- (void)viewDidLoad {

    [super viewDidLoad];
    [self setupMonospacedFontAttributes];
}


- (void)viewWillAppear:(BOOL)animated  {

    [super viewWillAppear:animated];

    [self.view layoutIfNeeded];
    [self.modePicker setupTextAttributes];
    [self.modePicker selectItemAtIndex:(NSInteger)[AppDelegate appDelegate].preferredSpecificGravityMode animated:NO];
}


- (void)viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];

    dispatch_async(dispatch_get_main_queue(), ^{ [self updateContent]; });
}


#pragma mark - Font Handling


- (void)setupMonospacedFontAttributes {

    for (UILabel *label in @[ self.originalGravity,
                              self.finalGravity,
                              self.actualFinalGravity,
                              self.attenuation,
                              self.realAttenuation,
                              self.alcoholByVolume,
                              ]) {
        label.font = [UIFont monospacedDigitFontVariant:label.font];
    }
}


#pragma mark - Content Rotation on iPad


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {

    NSInteger previousMode = (NSInteger)[AppDelegate appDelegate].preferredSpecificGravityMode;

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {

            [self.modePicker selectItemAtIndex:previousMode animated:NO];
        }
        completion:nil];
}


#pragma mark - Display Updates


- (BOOL)tryUpdateForRefractionBefore:(NSDecimalNumber *)beforeRefraction current:(NSDecimalNumber *)currentRefraction {

    self.beforeRefraction  = beforeRefraction;
    self.currentRefraction = currentRefraction;

    dispatch_async(dispatch_get_main_queue(), ^{ [self updateContent]; });

    return [beforeRefraction isGreaterThanOrEqual:currentRefraction];
}


- (void)updateContent {

    // Init with invalid information
    NSString *outOfRange = NSLocalizedString(kOutOfRangeKey, nil);

    self.originalGravity.text = kInvalidInput;
    self.originalGravity.accessibilityValue = outOfRange;

    self.finalGravity.text = kInvalidInput;
    self.finalGravity.accessibilityValue = outOfRange;

    self.actualFinalGravity.text = kInvalidInput;
    self.actualFinalGravity.accessibilityValue = outOfRange;

    self.attenuation.text = kInvalidInput;
    self.attenuation.accessibilityValue = outOfRange;

    self.realAttenuation.text = kInvalidInput;
    self.realAttenuation.accessibilityValue = outOfRange;

    self.alcoholByVolume.text = kInvalidInput;
    self.alcoholByVolume.accessibilityValue = outOfRange;


    if ([self.beforeRefraction isGreaterThan:[NSDecimalNumber zero]]) {

        // User preferences for units/modes
        AppDelegate *sharedAppDelegate = [AppDelegate appDelegate];
        RFGravityUnit preferredGravityUnit = sharedAppDelegate.preferredGravityUnit;
        RFSpecificGravityMode preferredGravityMode = sharedAppDelegate.preferredSpecificGravityMode;

        // Localized number formatters
        NSNumberFormatter *gravityFormatter = [AppDelegate numberFormatterForGravityUnit:preferredGravityUnit
                                                                     horizontalSizeClass:self.traitCollection.horizontalSizeClass
                                                                              accessible:NO];

        NSNumberFormatter *accessibleGravityFormatter = [AppDelegate numberFormatterForGravityUnit:preferredGravityUnit
                                                                               horizontalSizeClass:self.traitCollection.horizontalSizeClass
                                                                                        accessible:YES];

        NSNumberFormatter *attenuationFormatter = [AppDelegate numberFormatterAttenuation];
        NSNumberFormatter *alcoholFormatter = [AppDelegate numberFormatterPercentABV];


        // Original gravity
        NSDecimalNumber *originalGravity = [RefractometerComputation wortCorrectedRefraction:self.beforeRefraction];
        NSDecimalNumber *convertedGravity = [RefractometerComputation gravityFromPlato:originalGravity withGravityUnit:preferredGravityUnit];
        self.originalGravity.text = [gravityFormatter stringFromNumber:convertedGravity];
        self.originalGravity.accessibilityValue = [accessibleGravityFormatter stringFromNumber:convertedGravity];

        if ([self.currentRefraction isGreaterThan:[NSDecimalNumber zero]] && [self.currentRefraction isLessThan:self.beforeRefraction]) {

            // Apparent final gravity
            NSDecimalNumber *apparentFinalGravity = [RefractometerComputation apparentSpecificGravityForInitialRefraction:self.beforeRefraction finalRefraction:self.currentRefraction mode:preferredGravityMode];

            if ([apparentFinalGravity isGreaterThanOrEqual:[NSDecimalNumber one]]) {

                convertedGravity = [RefractometerComputation gravityFromSG:apparentFinalGravity withGravityUnit:preferredGravityUnit];
                self.finalGravity.text = [gravityFormatter stringFromNumber:convertedGravity];
                self.finalGravity.accessibilityValue = [accessibleGravityFormatter stringFromNumber:convertedGravity];

                // Actual final gravity
                NSDecimalNumber *actualFinalGravity = [RefractometerComputation trueSpecificGravityForApparentSpecificGravity:apparentFinalGravity initialRefraction:self.beforeRefraction];
                convertedGravity = [RefractometerComputation gravityFromSG:actualFinalGravity withGravityUnit:preferredGravityUnit];
                self.actualFinalGravity.text = [gravityFormatter stringFromNumber:convertedGravity];
                self.actualFinalGravity.accessibilityValue = [accessibleGravityFormatter stringFromNumber:convertedGravity];

                // Apparent attenuation
                NSDecimalNumber *apparentAttenuation = [RefractometerComputation attenuationForInitialRefraction:self.beforeRefraction currentSpecificGravity:apparentFinalGravity];
                self.attenuation.text = [attenuationFormatter stringFromNumber:apparentAttenuation];
                self.attenuation.accessibilityValue = self.attenuation.text;

                // Real attenuation
                NSDecimalNumber *realAttenuation = [RefractometerComputation attenuationForInitialRefraction:self.beforeRefraction currentSpecificGravity:actualFinalGravity];
                self.realAttenuation.text = [attenuationFormatter stringFromNumber:realAttenuation];
                self.realAttenuation.accessibilityValue = self.realAttenuation.text;

                // Alcohol by volume
                NSDecimalNumber *alcoholByVolume = [RefractometerComputation alcoholByVolumeForInitialRefraction:self.beforeRefraction apparentSpecificGravity:apparentFinalGravity];
                self.alcoholByVolume.text = [alcoholFormatter stringFromNumber:alcoholByVolume];
                self.alcoholByVolume.accessibilityValue = self.alcoholByVolume.text;
            }
        }
    }
}


#pragma mark - HorizontalPickerViewDatasource


- (NSInteger)numberOfItemsInPickerView:(HorizontalModePicker *)pickerView {

    return 4;
}


- (NSString *)pickerView:(HorizontalModePicker *)pickerView titleForItemAtIndex:(NSInteger)index {

    switch (index) {

        case 0: return NSLocalizedString(kModeStandardKey, nil);
        case 1: return NSLocalizedString(kModeKleierKey, nil);
        case 2: return NSLocalizedString(kModeTerrillLinearKey, nil);
        case 3: return NSLocalizedString(kModeTerrillCubicKey, nil);
    }

    return nil;
}


#pragma mark - HorizontalPickerViewDelegate


- (void)pickerView:(HorizontalModePicker *)pickerView didSelectItemAtIndex:(NSInteger)index {

    [AppDelegate appDelegate].preferredSpecificGravityMode = (RFSpecificGravityMode)index;

    dispatch_async(dispatch_get_main_queue(), ^{ [self updateContent]; });
}


#pragma mark - Accessibility


- (void)viewDidLayoutSubviews {

    void (^adjustAccessibilityFrame)(UIView *) = ^(UIView *view) {

        CGRect rect = [view convertRect:view.bounds toView:nil];
        rect = CGRectInset(rect, 0, -20);
        rect = CGRectOffset(rect, 0, 8);

        view.accessibilityFrame = rect;
        view.accessibilityActivationPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    };

    adjustAccessibilityFrame(self.originalGravity);
    adjustAccessibilityFrame(self.alcoholByVolume);
    adjustAccessibilityFrame(self.finalGravity);
    adjustAccessibilityFrame(self.actualFinalGravity);
    adjustAccessibilityFrame(self.attenuation);
    adjustAccessibilityFrame(self.realAttenuation);
}

@end
