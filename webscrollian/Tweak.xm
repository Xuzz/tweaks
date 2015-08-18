#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook UIWebBrowserView

+ (CGFloat)preferredScrollDecelerationFactor {
    return 1.007;
}

%end



