project(hpc-coding-conventions)

cmake_minimum_required(VERSION 3.7)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON PARENT_SCOPE)
include(cmake/bob.cmake)

function(bbp_enable_precommit)
  find_package(Python COMPONENTS Interpreter REQUIRED)
  find_package(PreCommit REQUIRED)
  execute_process(COMMAND ${PreCommit_EXECUTABLE} install)
  execute_process(
    COMMAND ${Python_EXECUTABLE}
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-setup-pre-commit-config.py"
            --clang-format ${BBP_USE_FORMATTING} --cmake-format
            ${BBP_USE_FORMATTING} ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR})
  add_custom_target(bbp-run-pre-commits ${PreCommit_EXECUTABLE} run --all-files)
endfunction(bbp_enable_precommit)

function(bbp_enable_formatting)
  find_package(Python COMPONENTS Interpreter REQUIRED)
  find_package(ClangFormat 7 EXACT REQUIRED)
  set(BBP_ClangFormat_OPTIONS "" CACHE STRING "clang-format options")
  set(BBP_ClangFormat_FILES_RE
      "^.*\\\\.c$$"
      "^.*\\\\.h$$"
      "^.*\\\\.cpp$$"
      "^.*\\\\.hpp$$"
      CACHE STRING "List of regular expressions matching C/C++ filenames")
  set(
    BBP_ClangFormat_EXCLUDES_RE ".*/third[-_]parties/.*$$"
    ".*/third[-_]party/.*$$"
    CACHE STRING
          "list of regular expressions to exclude C/C++ files from formatting")
  set(
    BBP_ClangFormat_DEPENDENCIES ""
    CACHE STRING "list of CMake targets to build before formatting C/C++ code")
  mark_as_advanced(BBP_ClangFormat_OPTIONS BBP_ClangFormat_FILES_RE
                   BBP_ClangFormat_EXCLUDES_RE)
  add_custom_target(bbp-cpp-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --clang-format="${ClangFormat_EXECUTABLE}"
                    --options
                    "${BBP_ClangFormat_OPTIONS}"
                    --files-re
                    ${BBP_ClangFormat_FILES_RE}
                    --excludes-re
                    ${BBP_ClangFormat_EXCLUDES_RE}
                    --
                    ${CMAKE_BINARY_DIR}/compile_commands.json
                    format)
  add_custom_target(bbp-check-cpp-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --clang-format="${ClangFormat_EXECUTABLE}"
                    --options
                    "${BBP_ClangFormat_OPTIONS}"
                    --files-re
                    ${BBP_ClangFormat_FILES_RE}
                    --excludes-re
                    ${BBP_ClangFormat_EXCLUDES_RE}
                    --
                    ${CMAKE_BINARY_DIR}/compile_commands.json
                    check)
  if(BBP_ClangFormat_DEPENDENCIES)
    add_dependencies(bbp-cpp-format ${BBP_ClangFormat_DEPENDENCIES})
    add_dependencies(bbp-check-cpp-format ${BBP_ClangFormat_DEPENDENCIES})
  endif()

  find_package(CMakeFormat REQUIRED)
  set(BBP_CMakeFormat_OPTIONS "" CACHE STRING "cmake-format options")
  set(BBP_CMakeFormat_FILES_RE "^.*\\\\.cmake$$" "^.*CMakeLists.txt$$"
      CACHE STRING "List of regular expressions matching CMake files")
  set(
    BBP_CMakeFormat_EXCLUDES_RE ".*/third[-_]parties/.*$$"
    ".*/third[-_]party/.*$$"
    CACHE STRING
          "list of regular expressions to exclude CMake files from formatting")
  mark_as_advanced(BBP_CMakeFormat_OPTIONS BBP_CMakeFormat_FILES_RE
                   BBP_CMakeFormat_EXCLUDES_RE)
  add_custom_target(bbp-cmake-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-cmake-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --cmake-format="${CMakeFormat_EXECUTABLE}"
                    --options
                    "${BBP_CMakeFormat_OPTIONS}"
                    --files-re
                    ${BBP_CMakeFormat_FILES_RE}
                    --excludes-re
                    ${BBP_CMakeFormat_EXCLUDES_RE}
                    --
                    format)
  add_custom_target(bbp-check-cmake-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-cmake-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --cmake-format="${CMakeFormat_EXECUTABLE}"
                    --options
                    "${BBP_CMakeFormat_OPTIONS}"
                    --files-re
                    ${BBP_CMakeFormat_FILES_RE}
                    --excludes-re
                    ${BBP_CMakeFormat_EXCLUDES_RE}
                    --
                    check)
endfunction(bbp_enable_formatting)

bob_option(BBP_USE_FORMATTING
           "Enable helpers to keep CMake and C++ code properly formatted" OFF)
bob_option(BBP_USE_PRECOMMIT "Enable automatic checks before git commits" OFF)

if(BBP_USE_FORMATTING)
  bbp_enable_formatting()
endif(BBP_USE_FORMATTING)

if(BBP_USE_PRECOMMIT)
  bbp_enable_precommit()
endif(BBP_USE_PRECOMMIT)
