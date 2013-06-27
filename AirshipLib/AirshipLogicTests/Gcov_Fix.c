/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
// This solution to the linker problem was found here:
// http://stackoverflow.com/questions/8732393/code-coverage-with-xcode-4-2-missing-files/8733416#8733416
// posted by iHunter JAN/2012
// referring to this document
// http://developer.apple.com/library/mac/#releasenotes/Darwin/SymbolVariantsRelNotes/_index.html
// explicity the following paragraph
//    The UNIX™ conformance variants use the $UNIX2003 suffix.
//
//    Important: The work for UNIX™ conformance started in Mac OS 10.4, but was not completed until 10.5. Thus, in the 10.4 versions of libSystem.dylib, many of the conforming variant symbols (with the $UNIX2003 suffix) exist. The list is not complete, and the conforming behavior of the variant symbols may not be complete, so they should be avoided.
//
//    Because the 64-bit environment has no legacy to maintain, it was created to be UNIX™ conforming from the start, without the use of the $UNIX2003 suffix. So, for example, _fputs$UNIX2003 in 32-bit and _fputs in 64-bit will have the same conforming behavior.
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