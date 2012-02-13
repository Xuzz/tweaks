#include <SpringBoard/SpringBoard.h>

// Works on iOS5, hopefully on iOS4 (this method is there)

%hook SBIcon
- (id)badgeNumberOrString {
	return nil;
}
%end