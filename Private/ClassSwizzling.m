//
//  ClassSwizzling.h
//  Aluxoft SCP
//
//  Created by Josejulio Martínez on 18/06/14.
//  Copyright (c) 2014 Josejulio Martínez. All rights reserved.
//

#import <objc/message.h>


static __attribute__((unused)) void classOverridingSelector(const char* newClassPrefix, id target, SEL originalSelector, SEL overrideSelector) {
    Class klass = [target class];
    NSString* className = NSStringFromClass(klass);
    if (strncmp(newClassPrefix, [className UTF8String], strlen(newClassPrefix)) != 0) {
        NSString* subclassName = [NSString stringWithFormat:@"%s%@", newClassPrefix, className];
        Class subclass = NSClassFromString(subclassName);
        if (subclass == nil) {
            subclass = objc_allocateClassPair(klass, [subclassName UTF8String], 0);
            if (subclass != nil) {
                objc_registerClassPair(subclass);
                Method swizzledMethod = class_getInstanceMethod(klass, overrideSelector);
                BOOL methodAdded = class_addMethod(subclass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
                NSCAssert(methodAdded, @"Adding a method to a class (new one) without own methods.");
            }
        }
        if (subclass != nil) {
            object_setClass(target, subclass);
        }
    }
}
