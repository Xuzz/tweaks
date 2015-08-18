%hook SBIconListPageControl
- (id)initWithFrame:(CGRect)frame
{
	if ((self = %orig)) self.hidden = YES;
	return self;
}
%end