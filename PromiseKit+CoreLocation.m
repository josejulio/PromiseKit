@import CoreLocation.CLLocationManagerDelegate;
#import "Private/PMKManualReference.h"
#import "PromiseKit+CoreLocation.h"
#import "PromiseKit/fwd.h"
#import "PromiseKit/Promise.h"
#include <objc/runtime.h>

#define PMKLocationManagerCondition @"PMKLocationManagerCondition"

@interface PMKLocationManager : CLLocationManager <CLLocationManagerDelegate>
@end



@implementation PMKLocationManager {
@public
    void (^fulfiller)(id);
    void (^rejecter)(id);
}

#define PMKLocationManagerCleanup() \
    [manager stopUpdatingLocation]; \
    self.delegate = nil; \
    objc_setAssociatedObject(manager, PMKLocationManagerCondition, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
    [self pmk_breakReference];

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    NSArray*(^condition)(CLLocationManager*, NSArray*) = objc_getAssociatedObject(manager, PMKLocationManagerCondition);
    if (condition) {
        locations = condition(locations.lastObject, locations);
        if ([locations count] == 0) {
            return;
        }
    }
    fulfiller(PMKManifold(locations.lastObject, locations));
    PMKLocationManagerCleanup();
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    rejecter(error);
    PMKLocationManagerCleanup();
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [manager startUpdatingLocation];
}

@end



@implementation CLLocationManager (PromiseKit)

+ (PMKPromise *)promise {
    return [self promiseIf:nil];
}

+ (PMKPromise *)promiseIf:(NSArray*(^)(CLLocationManager*, NSArray*)) condition {
    PMKLocationManager *manager = [PMKLocationManager new];
    manager.delegate = manager;
    [manager pmk_reference];
    
#if PMK_iOS8_ISH
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    SEL sel = @selector(requestWhenInUseAuthorization);
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined && [manager respondsToSelector:sel]) {
        [manager performSelector:sel];
    } else {
        [manager startUpdatingLocation];
    }
#else
    [manager startUpdatingLocation];
#pragma clang diagnostic pop
#pragma clang diagnostic pop
#endif
    
    if (condition) {
        objc_setAssociatedObject(manager, PMKLocationManagerCondition, condition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return [PMKPromise new:^(id fulfiller, id rejecter){
        manager->fulfiller = fulfiller;
        manager->rejecter = rejecter;
    }];
}

@end



@implementation CLGeocoder (PromiseKit)

+ (PMKPromise *)reverseGeocode:(CLLocation *)location {
    return [PMKPromise new:^(PMKPromiseFulfiller fulfiller, PMKPromiseRejecter rejecter) {
       [[CLGeocoder new] reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
            if (error) {
                rejecter(error);
            } else
                fulfiller(PMKManifold(placemarks.firstObject, placemarks));
        }];
    }];
}

+ (PMKPromise *)geocode:(id)address {
    return [PMKPromise new:^(PMKPromiseFulfiller fulfiller, PMKPromiseRejecter rejecter) {
        id handler = ^(NSArray *placemarks, NSError *error) {
            if (error) {
                rejecter(error);
            } else
                fulfiller(PMKManifold(placemarks.firstObject, placemarks));
        };
        if ([address isKindOfClass:[NSDictionary class]]) {
            [[CLGeocoder new] geocodeAddressDictionary:address completionHandler:handler];
        } else {
            [[CLGeocoder new] geocodeAddressString:address completionHandler:handler];
        }
    }];
}

@end
