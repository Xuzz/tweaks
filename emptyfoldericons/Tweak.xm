#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook SBFolderIcon
- (id)croppedImageForIcon:(id)arg1 { return nil; }
%end