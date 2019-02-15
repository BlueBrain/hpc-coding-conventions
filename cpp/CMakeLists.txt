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
            --clang-format ${${PROJECT_NAME}_FORMATTING} --cmake-format
            ${${PROJECT_NAME}_FORMATTING} ${CMAKE_SOURCE_DIR}
            ${CMAKE_BINARY_DIR})
  add_custom_target(git-pre-commits ${PreCommit_EXECUTABLE} run --all-files)
endfunction(bbp_enable_precommit)

function(bbp_enable_formatting)
  find_package(Python COMPONENTS Interpreter REQUIRED)
  find_package(ClangFormat 7 EXACT REQUIRED)
  set(${PROJECT_NAME}_ClangFormat_OPTIONS ""
      CACHE STRING "clang-format options")
  set(${PROJECT_NAME}_ClangFormat_FILES_RE
      "^.*\\\\.c$$"
      "^.*\\\\.h$$"
      "^.*\\\\.cpp$$"
      "^.*\\\\.hpp$$"
      CACHE STRING "List of regular expressions matching C/C++ filenames")
  set(
    ${PROJECT_NAME}_ClangFormat_EXCLUDES_RE ".*/third[-_]parties/.*$$"
    ".*/third[-_]party/.*$$"
    CACHE STRING
          "list of regular expressions to exclude C/C++ files from formatting")
  set(
    ${PROJECT_NAME}_ClangFormat_DEPENDENCIES ""
    CACHE STRING "list of CMake targets to build before formatting C/C++ code")
  mark_as_advanced(${PROJECT_NAME}_ClangFormat_OPTIONS
                   ${PROJECT_NAME}_ClangFormat_FILES_RE
                   ${PROJECT_NAME}_ClangFormat_EXCLUDES_RE)
  configure_file(.clang-format ${PROJECT_SOURCE_DIR})
  add_custom_target(clang-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --clang-format="${ClangFormat_EXECUTABLE}"
                    --options
                    "${${PROJECT_NAME}_ClangFormat_OPTIONS}"
                    --files-re
                    ${${PROJECT_NAME}_ClangFormat_FILES_RE}
                    --excludes-re
                    ${${PROJECT_NAME}_ClangFormat_EXCLUDES_RE}
                    --
                    ${CMAKE_BINARY_DIR}/compile_commands.json
                    format)
  add_custom_target(check-clang-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --clang-format="${ClangFormat_EXECUTABLE}"
                    --options
                    "${${PROJECT_NAME}_ClangFormat_OPTIONS}"
                    --files-re
                    ${${PROJECT_NAME}_ClangFormat_FILES_RE}
                    --excludes-re
                    ${${PROJECT_NAME}_ClangFormat_EXCLUDES_RE}
                    --
                    ${CMAKE_BINARY_DIR}/compile_commands.json
                    check)
  if(${PROJECT_NAME}_ClangFormat_DEPENDENCIES)
    add_dependencies(clang-format ${${PROJECT_NAME}_ClangFormat_DEPENDENCIES})
    add_dependencies(check-clang-format
                     ${${PROJECT_NAME}_ClangFormat_DEPENDENCIES})
  endif()

  find_package(CMakeFormat REQUIRED)
  set(${PROJECT_NAME}_CMakeFormat_OPTIONS ""
      CACHE STRING "cmake-format options")
  set(${PROJECT_NAME}_CMakeFormat_FILES_RE "^.*\\\\.cmake$$"
      "^.*CMakeLists.txt$$"
      CACHE STRING "List of regular expressions matching CMake files")
  set(
    ${PROJECT_NAME}_CMakeFormat_EXCLUDES_RE ".*/third[-_]parties/.*$$"
    ".*/third[-_]party/.*$$"
    CACHE STRING
          "list of regular expressions to exclude CMake files from formatting")
  mark_as_advanced(${PROJECT_NAME}_CMakeFormat_OPTIONS
                   ${PROJECT_NAME}_CMakeFormat_FILES_RE
                   ${PROJECT_NAME}_CMakeFormat_EXCLUDES_RE)
  add_custom_target(cmake-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-cmake-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --cmake-format="${CMakeFormat_EXECUTABLE}"
                    --options
                    "${${PROJECT_NAME}_CMakeFormat_OPTIONS}"
                    --files-re
                    ${${PROJECT_NAME}_CMakeFormat_FILES_RE}
                    --excludes-re
                    ${${PROJECT_NAME}_CMakeFormat_EXCLUDES_RE}
                    --
                    format)
  add_custom_target(check-cmake-format
                    ${Python_EXECUTABLE}
                    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-cmake-format.py"
                    -S
                    "${CMAKE_SOURCE_DIR}"
                    -B
                    "${CMAKE_BINARY_DIR}"
                    --cmake-format="${CMakeFormat_EXECUTABLE}"
                    --options
                    "${${PROJECT_NAME}_CMakeFormat_OPTIONS}"
                    --files-re
                    ${${PROJECT_NAME}_CMakeFormat_FILES_RE}
                    --excludes-re
                    ${${PROJECT_NAME}_CMakeFormat_EXCLUDES_RE}
                    --
                    check)
endfunction(bbp_enable_formatting)

bob_option(${PROJECT_NAME}_FORMATTING
           "Enable helpers to keep CMake and C++ code properly formatted" OFF)
bob_option(${PROJECT_NAME}_PRECOMMIT
           "Enable automatic checks before git commits" OFF)

if(${PROJECT_NAME}_FORMATTING)
  cmake_minimum_required(VERSION 3.12)
  bbp_enable_formatting()
endif(${PROJECT_NAME}_FORMATTING)

if(${PROJECT_NAME}_PRECOMMIT)
  cmake_minimum_required(VERSION 3.12)
  bbp_enable_precommit()
endif(${PROJECT_NAME}_PRECOMMIT)
