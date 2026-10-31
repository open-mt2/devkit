cmake_minimum_required(VERSION 3.20)
project(Metin2Client C CXX)

# Export compile commands for VSCode / clangd / ccls IntelliSense.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Options
option(BUILD_ARCH_X86 "Force 32-bit x86 target" OFF)
option(BUILD_TESTS "Build test binaries" ON)
if(BUILD_TESTS)
    enable_testing()
endif()

# Modules & platform setup
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Platform)

# The Linux package is relocatable: build.sh copies the non-system runtime
# libraries (libzip, libpython2.7) into dist/runtime. Resolve them relative to
# the executable so `cd dist && ./metin2client` works outside the image.
# Build-tree binaries keep CMake's automatic RPATH for CTest.
if(UNIX AND NOT APPLE)
    set(CMAKE_BUILD_RPATH "$ORIGIN/runtime")
    set(CMAKE_INSTALL_RPATH "$ORIGIN/runtime")
endif()

# Windows cross builds resolve most dependencies through the toolchain's
# OPENMT2_WIN64_DEPS_PREFIX, but packages that link via pkg-config (-lminiaudio,
# -lzip) only contribute the library name. Make the prefix a link directory
# (T1.9).
if(WIN32 AND OPENMT2_WIN64_DEPS_PREFIX)
    link_directories("${OPENMT2_WIN64_DEPS_PREFIX}/lib")
endif()

# Three consolidated source repositories (TB.3). Each repository adds its own
# packages in dependency order and pins the historic build/src/<Package>
# binary directories, so build.sh, the goldens and the dist assembly keep their
# paths.
set(OPENMT2_SOURCE_REPOS neoeter neoeter-python client)
set(_openmt2_consolidated FALSE)

foreach(_repo IN LISTS OPENMT2_SOURCE_REPOS)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/${_repo}/CMakeLists.txt")
        add_subdirectory("src/${_repo}" "${CMAKE_BINARY_DIR}/src/${_repo}")
        set(_openmt2_consolidated TRUE)
    endif()
endforeach()

if(NOT _openmt2_consolidated)
    # Legacy layout: 16 pkg_* checkouts driven by scripts/packages.map. Kept so
    # images built before the consolidation still configure.
    message(STATUS "OpenMT2: consolidated sources not found, using packages.map")
    set(OPENMT2_PACKAGE_DIRS "")
    set(OPENMT2_PACKAGE_MAP "${CMAKE_CURRENT_SOURCE_DIR}/scripts/packages.map")
    if(EXISTS "${OPENMT2_PACKAGE_MAP}")
        file(STRINGS "${OPENMT2_PACKAGE_MAP}" _package_map_lines)
        foreach(_line IN LISTS _package_map_lines)
            if(_line MATCHES "^pkg_[A-Za-z0-9_]+[ \t]*=[ \t]*([A-Za-z0-9_.-]+)")
                list(APPEND OPENMT2_PACKAGE_DIRS "${CMAKE_MATCH_1}")
            endif()
        endforeach()
    endif()

    foreach(_package IN LISTS OPENMT2_PACKAGE_DIRS)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/${_package}/CMakeLists.txt")
            add_subdirectory("src/${_package}")
        else()
            message(WARNING "OpenMT2 package '${_package}' not found under src/${_package}")
        endif()
    endforeach()

    # Pick up any pkg_* checkout that is not listed in packages.map yet.
    file(GLOB _source_dirs LIST_DIRECTORIES true "${CMAKE_CURRENT_SOURCE_DIR}/src/*")
    foreach(_dir IN LISTS _source_dirs)
        if(IS_DIRECTORY "${_dir}"
           AND EXISTS "${_dir}/CMakeLists.txt")
            get_filename_component(_name "${_dir}" NAME)
            if(NOT _name IN_LIST OPENMT2_PACKAGE_DIRS)
                message(STATUS "Adding unlisted OpenMT2 package: ${_name}")
                add_subdirectory("${_dir}")
            endif()
        endif()
    endforeach()
endif()

# T1.8: the fixed-function feature matrix is generated, never hand-written.
# Keep it in lockstep with the sources in CI (scripts/feature-matrix.sh --check).
if(BUILD_TESTS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/feature-matrix.sh")
    add_test(NAME feature_matrix
        COMMAND bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/feature-matrix.sh" --check
    )
    set_tests_properties(feature_matrix PROPERTIES
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
endif()

message(STATUS "Metin2 Client configured successfully.")
