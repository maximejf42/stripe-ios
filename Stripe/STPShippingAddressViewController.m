//
//  STPShippingAddressViewController.m
//  Stripe
//
//  Created by Ben Guo on 8/29/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPShippingAddressViewController.h"
#import "STPTheme.h"
#import "UIBarButtonItem+Stripe.h"
#import "UIViewController+Stripe_NavigationItemProxy.h"
#import "STPAddressViewModel.h"
#import "STPPaymentActivityIndicatorView.h"
#import "STPImageLibrary+Private.h"
#import "STPColorUtils.h"
#import "UIViewController+Stripe_KeyboardAvoiding.h"
#import "UIViewController+Stripe_ParentViewController.h"
#import "NSArray+Stripe_BoundSafe.h"
#import "UITableViewCell+Stripe_Borders.h"
#import "STPAddress.h"
#import "STPLocalizationUtils.h"
#import "STPShippingMethodsViewController.h"

@interface STPShippingAddressViewController ()<STPAddressViewModelDelegate, STPAddressFieldTableViewCellDelegate, UITableViewDelegate, UITableViewDataSource>
@property(nonatomic)STPPaymentConfiguration *configuration;
@property(nonatomic)STPTheme *theme;
@property(nonatomic, weak)UITableView *tableView;
@property(nonatomic, weak)UIImageView *imageView;
@property(nonatomic)UIBarButtonItem *nextItem;
@property(nonatomic)UIBarButtonItem *backItem;
@property(nonatomic)UIBarButtonItem *cancelItem;
@property(nonatomic)BOOL loading;
@property(nonatomic)STPPaymentActivityIndicatorView *activityIndicator;
@property(nonatomic)STPAddressViewModel *addressViewModel;
@end

@implementation STPShippingAddressViewController

- (instancetype)initWithConfiguration:(STPPaymentConfiguration *)configuration theme:(STPTheme *)theme {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _configuration = configuration;
        _theme = theme;
        // TODO: required fields?
        _addressViewModel = [[STPAddressViewModel alloc] initWithRequiredBillingFields:STPBillingAddressFieldsFull];
        _addressViewModel.delegate = self;
        self.title = [self titleForShippingType:self.configuration.shippingType];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    tableView.sectionHeaderHeight = 30;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    self.backItem = [UIBarButtonItem stp_backButtonItemWithTitle:STPLocalizedString(@"Back", @"Text for back button") style:UIBarButtonItemStylePlain target:self action:@selector(cancel:)];
    self.cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];

    UIBarButtonItem *nextItem;
    switch (self.configuration.shippingType) {
        case STPShippingTypeShipping:
            nextItem = [[UIBarButtonItem alloc] initWithTitle:STPLocalizedString(@"Next", nil)
                                                             style:UIBarButtonItemStyleDone
                                                            target:self
                                                            action:@selector(next:)];
            break;
        case STPShippingTypeDelivery:
            nextItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(next:)];
            break;
    }
    self.nextItem = nextItem;
    self.stp_navigationItemProxy.rightBarButtonItem = nextItem;
    self.stp_navigationItemProxy.rightBarButtonItem.enabled = NO;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[STPImageLibrary largeShippingImage]];
    imageView.contentMode = UIViewContentModeCenter;
    imageView.frame = CGRectMake(0, 0, self.view.bounds.size.width, imageView.bounds.size.height + (57 * 2));
    self.imageView = imageView;
    self.tableView.tableHeaderView = imageView;

    self.activityIndicator = [[STPPaymentActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 20.0f, 20.0f)];

    tableView.dataSource = self;
    tableView.delegate = self;
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(endEditing)]];
    [self updateAppearance];
}

- (void)endEditing {
    [self.view endEditing:NO];
}

- (void)updateAppearance {
    self.view.backgroundColor = self.theme.primaryBackgroundColor;
    [self.nextItem stp_setTheme:self.theme];
    [self.cancelItem stp_setTheme:self.theme];
    [self.backItem stp_setTheme:self.theme];
    self.tableView.allowsSelection = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = self.theme.primaryBackgroundColor;
    if ([STPColorUtils colorIsBright:self.theme.primaryBackgroundColor]) {
        self.tableView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
    } else {
        self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    }
    self.imageView.tintColor = self.theme.accentColor;
    self.activityIndicator.tintColor = self.theme.accentColor;
    for (STPAddressFieldTableViewCell *cell in self.addressViewModel.addressCells) {
        cell.theme = self.theme;
    }
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.stp_navigationItemProxy.leftBarButtonItem = [self stp_isAtRootOfNavigationController] ? self.cancelItem : self.backItem;
    [self.tableView reloadData];
    if (self.navigationController.navigationBar.translucent) {
        CGFloat insetTop = CGRectGetMaxY(self.navigationController.navigationBar.frame);
        self.tableView.contentInset = UIEdgeInsetsMake(insetTop, 0, 0, 0);
        self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
    } else {
        self.tableView.contentInset = UIEdgeInsetsZero;
        self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }
    CGPoint offset = self.tableView.contentOffset;
    offset.y = -self.tableView.contentInset.top;
    self.tableView.contentOffset = offset;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self stp_beginObservingKeyboardAndInsettingScrollView:self.tableView
                                             onChangeBlock:nil];
    [[self firstEmptyField] becomeFirstResponder];
}

- (UIResponder *)firstEmptyField {
    for (STPAddressFieldTableViewCell *cell in self.addressViewModel.addressCells) {
        if (cell.contents.length == 0) {
            return cell;
        }
    }
    return nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.view endEditing:YES];
}

- (void)setLoading:(BOOL)loading {
    if (loading == _loading) {
        return;
    }
    _loading = loading;
    [self.stp_navigationItemProxy setHidesBackButton:loading animated:YES];
    self.stp_navigationItemProxy.leftBarButtonItem.enabled = !loading;
    self.activityIndicator.animating = loading;
    if (loading) {
        [self.tableView endEditing:YES];
        UIBarButtonItem *loadingItem = [[UIBarButtonItem alloc] initWithCustomView:self.activityIndicator];
        [self.stp_navigationItemProxy setRightBarButtonItem:loadingItem animated:YES];
    } else {
        [self.stp_navigationItemProxy setRightBarButtonItem:self.nextItem animated:YES];
    }
    for (UITableViewCell *cell in self.addressViewModel.addressCells) {
        cell.userInteractionEnabled = !loading;
        [UIView animateWithDuration:0.1f animations:^{
            cell.alpha = loading ? 0.7f : 1.0f;
        }];
    }
}

- (void)cancel:(__unused id)sender {
    // TODO: tell delegate to cancel
}

- (void)next:(__unused id)sender {
    switch (self.configuration.shippingType) {
        case STPShippingTypeShipping: {
            // TODO: get shipping methods from delegate
            // TODO: check >0 shipping methods
            STPShippingMethod *method = [[STPShippingMethod alloc] init];
            method.label = @"UPS";
            method.detail = @"Arrives in 1-4 business days";
            method.amount = [NSDecimalNumber decimalNumberWithString:@"10.00"];
            STPShippingMethodsViewController *nextViewController = [[STPShippingMethodsViewController alloc] initWithShippingMethods:@[method] theme:self.theme];
            [self.navigationController pushViewController:nextViewController animated:YES];
            break;
        }
        case STPShippingTypeDelivery:
            // TODO: tell delegate to finish
            break;
    }
}

- (void)updateDoneButton {
    self.stp_navigationItemProxy.rightBarButtonItem.enabled = self.addressViewModel.isValid;
}

#pragma mark - STPAddressViewModelDelegate

- (void)addressViewModelDidChange:(__unused STPAddressViewModel *)addressViewModel {
    [self updateDoneButton];
}

- (void)addressFieldTableViewCellDidReturn:(__unused STPAddressFieldTableViewCell *)cell {
    // TODO: noop?
}

- (void)addressFieldTableViewCellDidUpdateText:(__unused STPAddressFieldTableViewCell *)cell {
    // TODO: noop?
}

- (void)addressFieldTableViewCellDidBackspaceOnEmpty:(__unused STPAddressFieldTableViewCell *)cell {
    // TODO: noop?
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(__unused UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(__unused UITableView *)tableView numberOfRowsInSection:(__unused NSInteger)section {
    return self.addressViewModel.addressCells.count;
}

- (UITableViewCell *)tableView:(__unused UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.addressViewModel.addressCells stp_boundSafeObjectAtIndex:indexPath.row];
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = self.theme.secondaryBackgroundColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL topRow = (indexPath.row == 0);
    BOOL bottomRow = ([self tableView:tableView numberOfRowsInSection:indexPath.section] - 1 == indexPath.row);
    [cell stp_setBorderColor:self.theme.tertiaryBackgroundColor];
    [cell stp_setTopBorderHidden:!topRow];
    [cell stp_setBottomBorderHidden:!bottomRow];
    [cell stp_setFakeSeparatorColor:self.theme.quaternaryBackgroundColor];
    [cell stp_setFakeSeparatorLeftInset:15.0f];
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForFooterInSection:(__unused NSInteger)section {
    return 27.0f;
}

- (CGFloat)tableView:(__unused UITableView *)tableView heightForHeaderInSection:(__unused NSInteger)section {
    return tableView.sectionHeaderHeight;
}

- (UIView *)tableView:(__unused UITableView *)tableView viewForHeaderInSection:(__unused NSInteger)section {
    UILabel *label = [UILabel new];
    label.font = self.theme.smallFont;
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.firstLineHeadIndent = 15;
    NSDictionary *attributes = @{NSParagraphStyleAttributeName: style};
    label.textColor = self.theme.secondaryForegroundColor;
    label.attributedText = [[NSAttributedString alloc] initWithString:[self labelForShippingType:self.configuration.shippingType] attributes:attributes];
    return label;
}

- (NSString *)labelForShippingType:(STPShippingType)type {
    switch (type) {
        case STPShippingTypeShipping:
            return STPLocalizedString(@"Shipping Address", @"Label for shipping address form");
            break;
        case STPShippingTypeDelivery:
            return STPLocalizedString(@"Delivery Address", @"Label for delivery address form");
            break;
    }
}

- (NSString *)titleForShippingType:(STPShippingType)type {
    switch (type) {
        case STPShippingTypeShipping:
            return STPLocalizedString(@"Shipping", @"Title for shipping info form");
            break;
        case STPShippingTypeDelivery:
            return STPLocalizedString(@"Delivery", @"Title for delivery info form");
            break;
    }
}

@end
