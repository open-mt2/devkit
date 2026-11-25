cmake_minimum_required(VERSION 3.20)
project(Metin2Client C CXX)

# Export compile commands for VSCode / clangd / ccls IntelliSense.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Options
option(BUILD_ARCH_X86 "Force 32-bit x86 target" OFF)
# This image is a build helper, not a test environment: never build test binaries.
option(BUILD_TESTS "Build test binaries" OFF)

# Modules & platform setup
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Platform)

# The Linux package is relocatable: build.sh copies the non-system runtime
# libraries (libzip, libpython2.7) into dist/runtime. Resolve them relative to
# the executable so `cd dist && ./openmt2` works outside the image.
# Build-tree binaries keep CMake's automatic RPATH.
if(UNIX AND NOT APPLE)
    set(CMAKE_BUILD_RPATH "$ORIGIN/runtime")
    set(CMAKE_INSTALL_RPATH "$ORIGIN/runtime")
endif()

# Windows cross builds resolve most dependencies through the toolchain's
# OPENMT2_WIN64_DEPS_PREFIX, but packages that link via pkg-config (-lzip)
# only contribute the library name. Make the prefix a link directory (T1.9).
if(WIN32 AND OPENMT2_WIN64_DEPS_PREFIX)
    link_directories("${OPENMT2_WIN64_DEPS_PREFIX}/lib")
endif()

# Consolidated source repositories (TB.3). Each repository adds its own
# packages in dependency order. neoeter-dotnet (the .NET 10 script runtime)
# sits next to neoeter-python; the client can run its scripts on either.
set(OPENMT2_SOURCE_REPOS neoeter neoeter-python neoeter-dotnet client)

option(OPENMT2_NEOETER_PREBUILT "Use an installed Neoeter instead of src/neoeter" OFF)

# The Windows cross toolchain has no win-x64 .NET host pack; opt in there.
if(WIN32 AND CMAKE_CROSSCOMPILING)
    set(_openmt2_dotnet_default OFF)
else()
    set(_openmt2_dotnet_default ON)
endif()
option(OPENMT2_SCRIPT_DOTNET "Build the .NET script runtime (neoeter-dotnet, needs the .NET 10 SDK)" ${_openmt2_dotnet_default})

foreach(_repo IN LISTS OPENMT2_SOURCE_REPOS)
    if(_repo STREQUAL "neoeter-dotnet" AND NOT OPENMT2_SCRIPT_DOTNET)
        message(STATUS "OpenMT2: .NET script runtime disabled (OPENMT2_SCRIPT_DOTNET=OFF)")
    elseif(_repo STREQUAL "neoeter" AND OPENMT2_NEOETER_PREBUILT)
        find_package(Neoeter CONFIG REQUIRED)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/${_repo}/CMakeLists.txt")
        add_subdirectory("src/${_repo}" "${CMAKE_BINARY_DIR}/src/${_repo}")
    else()
        message(FATAL_ERROR "OpenMT2 source repository '${_repo}' is missing under src/${_repo}. Run scripts/fetch-sources.sh.")
    endif()
endforeach()

message(STATUS "Metin2 Client configured successfully.")
