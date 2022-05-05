list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_MODULE_PATH
    ${CMAKE_MODULE_PATH}
    PARENT_SCOPE)
set(CMAKE_EXPORT_COMPILE_COMMANDS
    ON
    PARENT_SCOPE)
if(NOT CODING_CONV_PREFIX)
  set(CODING_CONV_PREFIX "${PROJECT_NAME}")
  set(CODING_CONV_PREFIX
      "${PROJECT_NAME}"
      PARENT_SCOPE)
endif(NOT CODING_CONV_PREFIX)
include(cmake/bob.cmake)
include(cmake/3rdparty.cmake)
include(cmake/build-time-copy.cmake)
include(cmake/bbp-find-python-module.cmake)

function(cpp_cc_enable_precommit)
  find_package(PythonInterp 3.5 REQUIRED)
  find_package(PreCommit REQUIRED)
  if(NOT EXISTS ${CMAKE_SOURCE_DIR}/.git/hooks/pre-commit)
    execute_process(COMMAND ${PreCommit_EXECUTABLE} install)
  endif()
  if(NOT EXISTS ${CMAKE_SOURCE_DIR}/.git/hooks/pre-push)
    execute_process(COMMAND ${PreCommit_EXECUTABLE} install --hook-type pre-push)
  endif()
  if(${CODING_CONV_PREFIX}_GIT_COMMIT_HOOKS MATCHES "courtesy-msg"
     OR ${CODING_CONV_PREFIX}_GIT_PUSH_HOOKS MATCHES "courtesy-msg")
    if(EXISTS ${PROJECT_SOURCE_DIR}/.git-push-message.cmake.in)
      configure_file(${PROJECT_SOURCE_DIR}/.git-push-message.cmake.in
                     ${PROJECT_BINARY_DIR}/git-push-message.cmake @ONLY)
    else()
      configure_file(cmake/git-push-message.cmake.in ${PROJECT_BINARY_DIR}/git-push-message.cmake
                     @ONLY)
    endif()
  endif()
  execute_process(
    COMMAND
      ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-setup-pre-commit-config.py"
      --commit-checks=${${CODING_CONV_PREFIX}_GIT_COMMIT_HOOKS}
      --push-checks=${${CODING_CONV_PREFIX}_GIT_PUSH_HOOKS} ${PROJECT_SOURCE_DIR}
      ${PROJECT_BINARY_DIR})
  add_custom_target(git-pre-commits ${PreCommit_EXECUTABLE} run --all-files)
endfunction(cpp_cc_enable_precommit)

function(cpp_cc_disable_precommit)
  if(EXISTS ${PROJECT_SOURCE_DIR}/.pre-commit-config.yaml)
    find_package(PythonInterp 3.5 REQUIRED)
    execute_process(
      COMMAND
        ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-setup-pre-commit-config.py"
        --commit-checks= --push-checks= ${PROJECT_SOURCE_DIR} ${PROJECT_BINARY_DIR})
  endif()
  file(REMOVE ${PROJECT_BINARY_DIR}/git-push-message.cmake)
endfunction(cpp_cc_disable_precommit)

function(cpp_cc_setup_tool_config name path)
  execute_process(COMMAND ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-${name}.py
                          --executable ${path} config RESULT_VARIABLE ${name}_config)
  if(NOT ${name}_config EQUAL 0)
    message(SEND_ERROR "Could not set up ${name} configuration")
  endif()
endfunction()

function(cpp_cc_enable_clang_formatting)
  find_package(PythonInterp 3.5 REQUIRED)
  set(ClangFormat_MIN_VERSION 7)
  if(NOT ${CODING_CONV_PREFIX}_ClangFormat_REQUIRED_VERSION)
    set(${CODING_CONV_PREFIX}_ClangFormat_REQUIRED_VERSION ${ClangFormat_MIN_VERSION})
  endif()
  find_package(ClangFormat ${${CODING_CONV_PREFIX}_ClangFormat_REQUIRED_VERSION} REQUIRED)
  if(NOT ClangFormat_FOUND)
    message(SEND_ERROR "Could not find Clang-Format")
    return()
  endif()

  set(${CODING_CONV_PREFIX}_ClangFormat_OPTIONS
      ""
      CACHE STRING "clang-format command options")
  set(${CODING_CONV_PREFIX}_ClangFormat_FILES_RE
      "^.*\\\\.cc?$$" "^.*\\\\.hh?$$" "^.*\\\\.[it]cc$$" "^.*\\\\.[chit]pp$$" "^.*\\\\.[chit]xx$$"
      CACHE STRING "List of regular expressions matching C/C++ filenames")
  set(${CODING_CONV_PREFIX}_ClangFormat_EXCLUDES_RE
      "third[-_]parties/.*$$" "third[-_]party/.*$$"
      CACHE STRING "list of regular expressions to exclude C/C++ files from formatting")
  set(${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES
      ""
      CACHE STRING "list of CMake targets to build before formatting C/C++ code")
  mark_as_advanced(
    ${CODING_CONV_PREFIX}_ClangFormat_OPTIONS ${CODING_CONV_PREFIX}_ClangFormat_FILES_RE
    ${CODING_CONV_PREFIX}_ClangFormat_EXCLUDES_RE)

  cpp_cc_setup_tool_config(clang-format ${ClangFormat_EXECUTABLE})
  set(clang_format_command_prefix
      ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-format.py" -S
      "${PROJECT_SOURCE_DIR}" "--executable=${ClangFormat_EXECUTABLE}" --files-re
      ${${CODING_CONV_PREFIX}_ClangFormat_FILES_RE} --excludes-re
      ${${CODING_CONV_PREFIX}_ClangFormat_EXCLUDES_RE} --)
  add_custom_target(clang-format ${clang_format_command_prefix} format --
                                 "${${CODING_CONV_PREFIX}_ClangFormat_OPTIONS}")
  add_custom_target(check-clang-format ${clang_format_command_prefix} check --
                                       "${${CODING_CONV_PREFIX}_ClangFormat_OPTIONS}")
  if(${CODING_CONV_PREFIX}_TEST_FORMATTING)
    add_test(NAME ClangFormat COMMAND ${clang_format_command_prefix} --make-unescape-re check --
                                      "${${CODING_CONV_PREFIX}_ClangFormat_OPTIONS}")
  endif()
  if(${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES)
    add_dependencies(clang-format ${${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES})
    add_dependencies(check-clang-format ${${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES})
  endif()
endfunction(cpp_cc_enable_clang_formatting)

function(cpp_cc_enable_cmake_formatting)
  find_package(PythonInterp 3.5 REQUIRED)
  if(NOT ${CODING_CONV_PREFIX}_CMakeFormat_REQUIRED_VERSION)
    set(${CODING_CONV_PREFIX}_CMakeFormat_REQUIRED_VERSION 0.6)
  endif()
  find_package(CMakeFormat ${${CODING_CONV_PREFIX}_CMakeFormat_REQUIRED_VERSION} REQUIRED)
  cmake_minimum_required(VERSION 3.10)
  if(CMakeFormat_FOUND AND CMakeFormat_VERSION VERSION_GREATER_EQUAL 0.7)
    message(SEND_ERROR "Unsupported cmake-format version.\
    Expects 0.6 <= version < 0.7 but found version ${CMakeFormat_VERSION}")
  endif()

  set(${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS
      ""
      CACHE STRING "cmake-format options")
  set(${CODING_CONV_PREFIX}_CMakeFormat_FILES_RE
      "^.*\\\\.cmake$$" "^.*CMakeLists.txt$$"
      CACHE STRING "List of regular expressions matching CMake files")
  set(${CODING_CONV_PREFIX}_CMakeFormat_EXCLUDES_RE
      "third[-_]parties/.*$$" "third[-_]party/.*$$"
      CACHE STRING "list of regular expressions to exclude CMake files from formatting")
  mark_as_advanced(
    ${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS ${CODING_CONV_PREFIX}_CMakeFormat_FILES_RE
    ${CODING_CONV_PREFIX}_CMakeFormat_EXCLUDES_RE)
  cpp_cc_setup_tool_config(cmake-format ${CMakeFormat_EXECUTABLE})
  set(cmake_format_command_prefix
      ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-cmake-format.py" -S
      "${PROJECT_SOURCE_DIR}" "--executable=${CMakeFormat_EXECUTABLE}" --files-re
      ${${CODING_CONV_PREFIX}_CMakeFormat_FILES_RE} --excludes-re
      ${${CODING_CONV_PREFIX}_CMakeFormat_EXCLUDES_RE} --)
  add_custom_target(cmake-format ${cmake_format_command_prefix} format --
                                 "${${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS}")
  add_custom_target(check-cmake-format ${cmake_format_command_prefix} check --
                                       ${${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS})
  if(${CODING_CONV_PREFIX}_TEST_FORMATTING)
    add_test(NAME CMakeFormat COMMAND ${cmake_format_command_prefix} --make-unescape-re check --
                                      ${${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS})
  endif()

endfunction(cpp_cc_enable_cmake_formatting)

function(cpp_cc_enable_static_analysis)
  find_package(PythonInterp 3.5 REQUIRED)
  set(ClangTidy_MIN_VERSION 7)
  if(NOT ${CODING_CONV_PREFIX}_ClangTidy_REQUIRED_VERSION)
    set(${CODING_CONV_PREFIX}_ClangTidy_REQUIRED_VERSION ${ClangTidy_MIN_VERSION})
  endif()

  find_package(ClangTidy ${${CODING_CONV_PREFIX}_ClangTidy_REQUIRED_VERSION} REQUIRED)
  set(${CODING_CONV_PREFIX}_ClangTidy_OPTIONS
      -extra-arg=-Wno-unknown-warning-option
      CACHE STRING "clang-tidy command options")
  mark_as_advanced(${CODING_CONV_PREFIX}_ClangTidy_OPTIONS)
  set(${CODING_CONV_PREFIX}_ClangTidy_FILES_RE
      "^.*\\\\.cc$$" "^.*\\\\.cpp$$" "^.*\\\\.cxx$$"
      CACHE STRING "List of regular expressions matching C/C++ filenames")
  set(${CODING_CONV_PREFIX}_ClangTidy_EXCLUDES_RE
      "third[-_]parties/.*$$" "third[-_]party/.*$$"
      CACHE STRING "list of regular expressions to exclude C/C++ files from formatting")
  set(${CODING_CONV_PREFIX}_ClangTidy_DEPENDENCIES
      ""
      CACHE STRING "list of CMake targets to build before formatting C/C++ code")
  mark_as_advanced(${CODING_CONV_PREFIX}_ClangTidy_OPTIONS ${CODING_CONV_PREFIX}_ClangTidy_FILES_RE
                   ${CODING_CONV_PREFIX}_ClangTidy_EXCLUDES_RE)
  cpp_cc_setup_tool_config(clang-tidy ${ClangTidy_EXECUTABLE})
  set(clang_tidy_command_prefix
      ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-tidy.py" -S
      "${PROJECT_SOURCE_DIR}" "--executable=${ClangTidy_EXECUTABLE}" --files-re
      "${${CODING_CONV_PREFIX}_ClangTidy_FILES_RE}" --excludes-re
      ${${CODING_CONV_PREFIX}_ClangTidy_EXCLUDES_RE} -p ${PROJECT_BINARY_DIR}/compile_commands.json
      check)
  add_custom_target(clang-tidy ${clang_tidy_command_prefix} --
                               ${${CODING_CONV_PREFIX}_ClangTidy_OPTIONS})
  if(${CODING_CONV_PREFIX}_TEST_STATIC_ANALYSIS)
    add_test(NAME ClangTidy COMMAND ${clang_tidy_command_prefix} --make-unescape-re --
                                    ${${CODING_CONV_PREFIX}_ClangTidy_OPTIONS})
  endif()
  if(${CODING_CONV_PREFIX}_ClangTidy_DEPENDENCIES)
    add_dependencies(clang-tidy ${${CODING_CONV_PREFIX}_ClangTidy_DEPENDENCIES})
  endif()

endfunction(cpp_cc_enable_static_analysis)

bob_option(${CODING_CONV_PREFIX}_FORMATTING
           "Enable helpers to keep CMake and C++ code properly formatted" OFF)
bob_option(${CODING_CONV_PREFIX}_TEST_FORMATTING "Add CTest formatting test" OFF)
bob_option(${CODING_CONV_PREFIX}_CLANG_FORMAT "Enable helper to keep C++ code properly formatted"
           OFF)
bob_option(${CODING_CONV_PREFIX}_CMAKE_FORMAT "Enable helper to keep CMake code properly formatted"
           OFF)

bob_option(${CODING_CONV_PREFIX}_GIT_HOOKS
           "Enable automatic checks when committing and pushing changes" OFF)
bob_input(${CODING_CONV_PREFIX}_GIT_COMMIT_HOOKS "" STRING
          "Comma-separated list of checks to perform when committing changes")
bob_input(${CODING_CONV_PREFIX}_GIT_PUSH_HOOKS "courtesy-msg" STRING
          "Comma-separated list of checks to perform when pushing changes")

bob_option(${CODING_CONV_PREFIX}_STATIC_ANALYSIS "Enable C++ static analysis during compilation"
           OFF)
bob_option(${CODING_CONV_PREFIX}_TEST_STATIC_ANALYSIS "Add CTest static analysis test" OFF)

if(${CODING_CONV_PREFIX}_CLANG_FORMAT OR ${CODING_CONV_PREFIX}_FORMATTING)
  cpp_cc_enable_clang_formatting()
endif()

if(${CODING_CONV_PREFIX}_CMAKE_FORMAT OR ${CODING_CONV_PREFIX}_FORMATTING)
  cpp_cc_enable_cmake_formatting()
endif()

if(${CODING_CONV_PREFIX}_GIT_HOOKS)
  cpp_cc_enable_precommit()
else()
  cpp_cc_disable_precommit()
endif()

if(${CODING_CONV_PREFIX}_STATIC_ANALYSIS)
  cmake_minimum_required(VERSION 3.6)
  cpp_cc_enable_static_analysis()
  set(CMAKE_CXX_CLANG_TIDY
      "${ClangTidy_EXECUTABLE}" -p "${PROJECT_BINARY_DIR}/compile_commands.json"
      ${${CODING_CONV_PREFIX}_ClangTidy_OPTIONS}
      PARENT_SCOPE)
endif(${CODING_CONV_PREFIX}_STATIC_ANALYSIS)
