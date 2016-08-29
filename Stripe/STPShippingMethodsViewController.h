//
//  STPShippingMethodsViewController.h
//  Stripe
//
//  Created by Ben Guo on 8/29/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STPShippingMethod.h"
#import "STPTheme.h"

@interface STPShippingMethodsViewController : UIViewController

- (instancetype)initWithShippingMethods:(NSArray<STPShippingMethod *>*)methods theme:(STPTheme *)theme;

@end
