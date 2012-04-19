//
//  Gcov_Fix.c
//  PushSampleLib
//
//  Created by Matt Hooge on 2/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//


#include <stdio.h>

//
// This file provides a workaround for an error that sometimes occurs when enabling code coverage
// metrics on iOS using LLVM/Clang and libprofile_rt.dylib:
//
//   Detected an attempt to call a symbol in system libraries that is not present on the iPhone:
//   fopen$UNIX2003 called from function llvm_gcda_start_file in image ...
//
// To fix this problem simply include this file in your testing target build.
//

FILE *fopen$UNIX2003(const char *filename, const char *mode);
size_t fwrite$UNIX2003(const void *ptr, size_t size, size_t nitems, FILE *stream);

FILE *fopen$UNIX2003(const char *filename, const char *mode) {
    return fopen(filename, mode);
}

size_t fwrite$UNIX2003(const void *ptr, size_t size, size_t nitems, FILE *stream) {
    return fwrite(ptr, size, nitems, stream);
}