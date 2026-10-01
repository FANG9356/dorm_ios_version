#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "AppIconPreviewDark" asset catalog image resource.
static NSString * const ACImageNameAppIconPreviewDark AC_SWIFT_PRIVATE = @"AppIconPreviewDark";

/// The "AppIconPreviewDefault" asset catalog image resource.
static NSString * const ACImageNameAppIconPreviewDefault AC_SWIFT_PRIVATE = @"AppIconPreviewDefault";

/// The "AppIconPreviewLight" asset catalog image resource.
static NSString * const ACImageNameAppIconPreviewLight AC_SWIFT_PRIVATE = @"AppIconPreviewLight";

/// The "AppIconPreviewMinimal" asset catalog image resource.
static NSString * const ACImageNameAppIconPreviewMinimal AC_SWIFT_PRIVATE = @"AppIconPreviewMinimal";

/// The "DormiNetLogo" asset catalog image resource.
static NSString * const ACImageNameDormiNetLogo AC_SWIFT_PRIVATE = @"DormiNetLogo";

#undef AC_SWIFT_PRIVATE
