#!/bin/bash
# (c) 2010 James Briant, binaryfinery.com
# Edited by Pierre de La Morinerie

if [[ "$TARGET_BUILD_DIR" == *iphoneos* ]] && [[ $ARCHS == *\ * ]]
then

echo "Rebuilding library as proper multiarch file"

LIB_ARM6="$TEMP_FILES_DIR/Objects-$BUILD_VARIANTS/armv6/$EXECUTABLE_NAME"
LIB_ARM7="$TEMP_FILES_DIR/Objects-$BUILD_VARIANTS/armv7/$EXECUTABLE_NAME"

# Libtool skrewed up, and built fat binaries in place of the arch-specific ones : strip them.
lipo "$LIB_ARM6" -remove armv7 -o "$LIB_ARM6" 2>/dev/null
lipo "$LIB_ARM7" -remove armv6 -o "$LIB_ARM7" 2>/dev/null

# Now recombine the stripped lib to the final product
libtool -static "$LIB_ARM6" "$LIB_ARM7" -o "$BUILT_PRODUCTS_DIR/$EXECUTABLE_NAME"

else
echo "Skipping arm multi-architecture rebuild"
fi


