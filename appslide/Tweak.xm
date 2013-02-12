#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static int enabled = 1;
static NSMutableArray *appstack = [[NSMutableArray alloc] init];
static id toapp = nil;
static id fromapp = nil;

static void SlideToApp(NSString *identifier) {
    id app = [[objc_getClass("SBApplicationController") sharedInstance] applicationWithDisplayIdentifier:identifier];
    [[objc_getClass("SBUIController") sharedInstance] activateApplicationFromSwitcher:app];
}

static NSString *Previous(NSArray *element) {
    return [element objectAtIndex:0];
}

static NSString *Next(NSArray *element) {
    return [element objectAtIndex:1];
}

static NSArray *Make(NSString *previous, NSString *next) {
    return [NSArray arrayWithObjects:previous, next, nil];
}

%hook SBAppSwitcherController
- (void)iconTapped:(id)icon {
    // don't slide if you tapped it in the switcher
    enabled -= 1;
    %orig;
}
%end

%hook SBUIController

- (void)activateURLFromBulletinList:(id)bulletinList {
    // don't slide in from notification center widgets
    enabled -= 1;	
    %orig;
}

static void begintransition(id from, id to) {
    if (from != nil && to != nil) {
        fromapp = from;
        toapp = to;
    } else {
        enabled -= 1;
    }
}
- (void)_beginTransitionFromApp:(id)from toApp:(id)to {
    begintransition(from, to);
    %orig;
}
- (void)_beginAppToAppTransition:(id)from to:(id)to {
    begintransition(from, to);
    %orig;
}
%end

%hook SBBannerController
//disable appslide when a "slid-up" app is already in view
- (void)_handleBannerTapGesture:(id)arg1
{
	if (appstack.count > 0)
		enabled -= 1;
	%orig;
}

%end

@interface SBAppToAppTransitionController
- (UIApplication *)deactivatingApp;
- (UIApplication *)activatingApp;
@end

%hook SBAppToAppTransitionController
//iOS 6 fix. _beginAppToAppTransition:to: and _beginTransitionFromApp:toApp: do not exist anymore
- (void)_startAnimation
{	
	if (self.activatingApp != nil && self.deactivatingApp != nil)
	{
		fromapp = self.deactivatingApp;
		toapp = self.activatingApp;		
	}
	else
	{
		enabled -= 1;
	}	
	
	%orig;
}

%end

%hook SBAppDosadoView
static BOOL transition(id self) {
    if (enabled <= 0) {
        // after a non-enabled transition, drop all
        // state so we don't try and go back from that
        // or something equally weird like that.
        enabled = 1;
        [appstack removeAllObjects];
	    return YES;
    }

    UIView *from = MSHookIvar<UIView *>(self, "_fromView");
    UIView *to = MSHookIvar<UIView *>(self, "_toView");

    BOOL downwards = NO;

    if ([appstack count] > 0 && [Previous([appstack lastObject]) isEqual:[toapp displayIdentifier]]) {
        [appstack removeLastObject];
        downwards = YES;
    } else {
        [appstack addObject:Make([fromapp displayIdentifier], [toapp displayIdentifier])];
        downwards = NO;
    }

    [self addSubview:(downwards ? to : from)];
    [self addSubview:(downwards ? from : to)];

    CGRect start;
    start.origin = CGPointMake(0, downwards ? 0 : [to bounds].size.height);
    start.size = [to bounds].size;
    [(downwards ? from : to) setFrame:start];

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationDelegate:self];

    if ([self respondsToSelector:@selector(_animationDidStop:)])
        [UIView setAnimationDidStopSelector:@selector(_animationDidStop:)];
    else if ([self respondsToSelector:@selector(animationDidStop:finished:)])
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];

    CGRect done;
    done.origin = CGPointMake(0, downwards ? [to bounds].size.height : 0);
    done.size = [to bounds].size;
    [(downwards ? from : to) setFrame:done];

    [UIView commitAnimations];

    // reset enabled state for next time
    enabled = 1;

    return NO;
}
- (void)beginTransition {
    if (transition(self)) %orig;
}
- (void)_beginTransition {
    if (transition(self)) %orig;
}
%end

// workaround some weird activator bug where it gives me
// the same exact event twice in a row. wtf?
static BOOL ignore = NO;

@interface AppSlideActivator : NSObject { }
@end

@implementation AppSlideActivator
- (void)stopIgnoring {
    ignore = NO;
}
- (void)activator:(id)activator receiveEvent:(id)event 
{       
    if (ignore) {
        [event setHandled:YES];
        return;
    }

    if ([appstack count] > 0 && Previous([appstack lastObject]) != nil) {
    	SlideToApp(Previous([appstack lastObject]));
    	[event setHandled:YES];
       	ignore = YES;
	   	[self performSelector:@selector(stopIgnoring) withObject:nil afterDelay:0.6f];
    }
}
@end

__attribute__((constructor)) static void init() {
    // make sure activator is loaded
    dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);

    static AppSlideActivator *listener = nil;
    listener = [[AppSlideActivator alloc] init];

    // default to single home button press
    // single press is messed in iOS6, so hardcode activator menu single press action
    id la = [objc_getClass("LAActivator") sharedInstance];
    if ([la respondsToSelector:@selector(hasSeenListenerWithName:)] && [la respondsToSelector:@selector(assignEvent:toListenerWithName:)])
        if (![la hasSeenListenerWithName:@"com.chpwn.appslide"])
            [la assignEvent:[objc_getClass("LAEvent") eventWithName:@"libactivator.menu.press.single"] toListenerWithName:@"com.chpwn.appslide"];

    // register our listener. do this after the above so it still hasn't "seen" us if this is first launch
    [[objc_getClass("LAActivator") sharedInstance] registerListener:listener forName:@"com.chpwn.appslide"];

    %init;
}

