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

# The packages are cloned into src/<Name> by scripts/fetch-packages.sh. Read
# the ordered mapping from scripts/packages.map so the dependency build order
# has a single source of truth.
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

# Pick up any pkg_* checkout that is not listed in packages.map yet. Unknown
# packages are built after the ordered list.
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

message(STATUS "Metin2 Client configured successfully.")
