# cmake/Platform.cmake - Compiler flags & platform configuration

# C++ Standard configuration
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Platform detection
if(WIN32)
    message(STATUS "Target Platform: Windows")
    add_compile_definitions(
        OPENMT2_PLATFORM_WINDOWS=1
        OPENMT2_SDL_WINDOW=1
        WIN32
        _WINDOWS
        _CRT_SECURE_NO_WARNINGS
    )
    if(MSVC)
        add_compile_options(
            /W4
            /MP
            /EHsc
        )
    endif()

    # Cross-built dependency prefix (T2.3): zlib, lzo2, libzip, SDL2, miniaudio.
    if(DEFINED OPENMT2_WIN64_DEPS_PREFIX AND EXISTS "${OPENMT2_WIN64_DEPS_PREFIX}")
        include_directories(SYSTEM "${OPENMT2_WIN64_DEPS_PREFIX}/include")
        link_directories("${OPENMT2_WIN64_DEPS_PREFIX}/lib")
    endif()
else()
    message(STATUS "Target Platform: Linux / POSIX")
    add_compile_definitions(
        OPENMT2_PLATFORM_LINUX=1
        OPENMT2_RENDERER_GL=1
        OPENMT2_SDL_WINDOW=1
        _GNU_SOURCE
    )

    # GCC / Clang warning and compatibility flags
    add_compile_options(
        -Wall
        -Wextra
        -Wno-unused-parameter
        -Wno-invalid-offsetof
        -Wno-multichar
        -Wno-sign-compare
        -fPIC
    )

    # If building 32-bit explicitly:
    if(BUILD_ARCH_X86)
        message(STATUS "Target Architecture: x86 (32-bit)")
        add_compile_options(-m32)
        add_link_options(-m32)
    else()
        message(STATUS "Target Architecture: x86_64 (64-bit default)")
    endif()
endif()
