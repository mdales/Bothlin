//
//  Helpers.h
//  Bothlin
//
//  Created by Michael Dales on 30/09/2023.
//

#ifndef Helpers_h
#define Helpers_h

#define _start_with_at() autoreleasepool{};

#define weakify(_x) \
    _start_with_at() \
    __weak typeof(_x) weak##_x = _x;

#define strongify(_x) \
    _start_with_at() \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
    __strong typeof(_x) _x = weak##_x; \
    _Pragma("clang diagnostic pop") 


#endif /* Helpers_h */