list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_MODULE_PATH
    ${CMAKE_MODULE_PATH}
    PARENT_SCOPE)
set(CMAKE_EXPORT_COMPILE_COMMANDS
    ON
    PARENT_SCOPE)
if(NOT CODING_CONV_PREFIX)
  set(CODING_CONV_PREFIX "${PROJECT_NAME}")
  set(CODING_CONV_PREFIX "${PROJECT_NAME}" PARENT_SCOPE)
endif(NOT CODING_CONV_PREFIX)
include(cmake/bob.cmake)

function(bbp_enable_precommit)
  find_package(PythonInterp 3.5 REQUIRED)
  find_package(PreCommit REQUIRED)
  execute_process(COMMAND ${PreCommit_EXECUTABLE} install)
  execute_process(
    COMMAND
      ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-setup-pre-commit-config.py"
      --force ${${CODING_CONV_PREFIX}_PRECOMMIT_REGEN} --clang-format
      ${${CODING_CONV_PREFIX}_FORMATTING} --cmake-format ${${CODING_CONV_PREFIX}_FORMATTING}
      --clang-tidy ${${CODING_CONV_PREFIX}_STATIC_ANALYSIS} ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR})
  add_custom_target(git-pre-commits ${PreCommit_EXECUTABLE} run --all-files)
endfunction(bbp_enable_precommit)

function(bbp_disable_precommit)
  if(EXISTS ${CMAKE_SOURCE_DIR}/.pre-commit-config.yaml)
    find_package(PythonInterp 3.5 REQUIRED)
    execute_process(
      COMMAND
        ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-setup-pre-commit-config.py"
        --clang-format off --cmake-format off --clang-tidy off ${CMAKE_SOURCE_DIR}
        ${CMAKE_BINARY_DIR})
  endif()
endfunction(bbp_disable_precommit)

function(bbp_enable_clang_formatting)
  find_package(PythonInterp 3.5 REQUIRED)
  find_package(ClangFormat REQUIRED)
  if(NOT ClangFormat_FOUND)
    message(SEND_ERROR "Could not find Clang-Format")
    return()
  endif()
  if(ClangFormat_VERSION_MAJOR GREATER 6 AND ClangFormat_VERSION_MAJOR LESS 12)
    set(${CODING_CONV_PREFIX}_ClangFormat_CONFIG_FILE clang-format-${ClangFormat_VERSION_MAJOR})
  else()
    message(
      SEND_ERROR
        "Unsupported Clang-Format version ${ClangFormat_VERSION}. Supported versions are 7 or higher."
    )
  endif()

  set(${CODING_CONV_PREFIX}_ClangFormat_OPTIONS
      ""
      CACHE STRING "clang-format command options")
  set(${CODING_CONV_PREFIX}_ClangFormat_FILES_RE
      "^.*\\\\.cc?$$" "^.*\\\\.hh?$$" "^.*\\\\.[it]cc$$" "^.*\\\\.[chit]pp$$" "^.*\\\\.[chit]xx$$"
      CACHE STRING "List of regular expressions matching C/C++ filenames")
  set(${CODING_CONV_PREFIX}_ClangFormat_EXCLUDES_RE
      ".*/third[-_]parties/.*$$" ".*/third[-_]party/.*$$"
      CACHE STRING "list of regular expressions to exclude C/C++ files from formatting")
  set(${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES
      ""
      CACHE STRING "list of CMake targets to build before formatting C/C++ code")
  mark_as_advanced(${CODING_CONV_PREFIX}_ClangFormat_OPTIONS ${CODING_CONV_PREFIX}_ClangFormat_FILES_RE
                   ${CODING_CONV_PREFIX}_ClangFormat_EXCLUDES_RE)
  execute_process(
    COMMAND git ls-files --error-unmatch .clang-format
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE is_clang_format_config_tracked
    ERROR_QUIET)
  if(NOT is_clang_format_config_tracked EQUAL 0)
    if(EXISTS ${PROJECT_SOURCE_DIR}/.clang-format.changes)
      execute_process(
        COMMAND ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cpplib.py" merge-yaml
                "${CMAKE_CURRENT_SOURCE_DIR}/${${CODING_CONV_PREFIX}_ClangFormat_CONFIG_FILE}"
                "${PROJECT_SOURCE_DIR}/.clang-format.changes" "${PROJECT_SOURCE_DIR}/.clang-format")
    else()
      configure_file(${${CODING_CONV_PREFIX}_ClangFormat_CONFIG_FILE}
                     ${PROJECT_SOURCE_DIR}/.clang-format COPYONLY)
    endif()
  endif()
  unset(is_clang_format_config_tracked)

  set(clang_format_command_prefix
      ${PYTHON_EXECUTABLE}
      "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-format.py"
      -S
      "${CMAKE_SOURCE_DIR}"
      -B
      "${CMAKE_BINARY_DIR}"
      "--executable=${ClangFormat_EXECUTABLE}"
      "--clang-format-diff-executable=${ClangFormatDiff_EXECUTABLE}"
      "--changes-only=${${CODING_CONV_PREFIX}_FORMATTING_CPP_CHANGES_ONLY}"
      --files-re
      ${${CODING_CONV_PREFIX}_ClangFormat_FILES_RE}
      $<$<BOOL:${CODING_CONV_PREFIX}_FORMATTING_NO_SUBMODULES>:--git-modules>
      --excludes-re
      ${${CODING_CONV_PREFIX}_ClangFormat_EXCLUDES_RE}
      -p
      ${CMAKE_BINARY_DIR}/compile_commands.json
      --applies-on=${${CODING_CONV_PREFIX}_FORMATTING_ON})
  add_custom_target(clang-format ${clang_format_command_prefix} --action format --
                    "${${CODING_CONV_PREFIX}_ClangFormat_OPTIONS}")
  add_custom_target(check-clang-format ${clang_format_command_prefix} --action check --
                    "${${CODING_CONV_PREFIX}_ClangFormat_OPTIONS}")
  if(${CODING_CONV_PREFIX}_TEST_FORMATTING)
    add_test(NAME ClangFormat
             COMMAND ${clang_format_command_prefix} --action check --make-unescape-re --
                     "${${CODING_CONV_PREFIX}_ClangFormat_OPTIONS}")
  endif()
  if(${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES)
    add_dependencies(clang-format ${${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES})
    add_dependencies(check-clang-format ${${CODING_CONV_PREFIX}_ClangFormat_DEPENDENCIES})
  endif()
endfunction(bbp_enable_clang_formatting)

function(bbp_enable_cmake_formatting)
  find_package(PythonInterp 3.5 REQUIRED)
  find_package(CMakeFormat 0.6 REQUIRED)
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
      ".*/third[-_]parties/.*$$" ".*/third[-_]party/.*$$"
      CACHE STRING "list of regular expressions to exclude CMake files from formatting")
  mark_as_advanced(${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS ${CODING_CONV_PREFIX}_CMakeFormat_FILES_RE
                   ${CODING_CONV_PREFIX}_CMakeFormat_EXCLUDES_RE)
  execute_process(
    COMMAND git ls-files --error-unmatch .cmake-format
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE is_cmake_format_config_tracked
    ERROR_QUIET)
  if(NOT is_cmake_format_config_tracked EQUAL 0)
    if(EXISTS ${PROJECT_SOURCE_DIR}/.cmake-format.changes.yaml)
      execute_process(
        COMMAND
          ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cpplib.py" merge-yaml
          "${CMAKE_CURRENT_SOURCE_DIR}/cmake-format.yaml"
          "${PROJECT_SOURCE_DIR}/.cmake-format.changes.yaml"
          "${PROJECT_SOURCE_DIR}/.cmake-format.yaml")
    else()
      configure_file(cmake-format.yaml ${PROJECT_SOURCE_DIR}/.cmake-format.yaml COPYONLY)
    endif()
  endif()
  set(cmake_format_command_prefix
      ${PYTHON_EXECUTABLE}
      "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-cmake-format.py"
      -S
      "${CMAKE_SOURCE_DIR}"
      -B
      "${CMAKE_BINARY_DIR}"
      "--executable=${CMakeFormat_EXECUTABLE}"
      --files-re
      ${${CODING_CONV_PREFIX}_CMakeFormat_FILES_RE}
      $<$<BOOL:${CODING_CONV_PREFIX}_FORMATTING_NO_SUBMODULES>:--git-modules>
      --excludes-re
      ${${CODING_CONV_PREFIX}_CMakeFormat_EXCLUDES_RE}
      --applies-on=${${CODING_CONV_PREFIX}_FORMATTING_ON})
  add_custom_target(cmake-format ${cmake_format_command_prefix} --action format --
                    "${${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS}")
  add_custom_target(check-cmake-format ${cmake_format_command_prefix} --action check --
                    ${${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS})
  if(${CODING_CONV_PREFIX}_TEST_FORMATTING)
    add_test(NAME CMakeFormat
             COMMAND ${cmake_format_command_prefix} --action check --make-unescape-re --
                     ${${CODING_CONV_PREFIX}_CMakeFormat_OPTIONS})
  endif()

endfunction(bbp_enable_cmake_formatting)

function(bbp_enable_static_analysis)
  find_package(PythonInterp 3.5 REQUIRED)
  find_package(ClangTidy 7 EXACT REQUIRED)
  set(${CODING_CONV_PREFIX}_ClangTidy_OPTIONS
      -extra-arg=-Wno-unknown-warning-option
      CACHE STRING "clang-tidy command options")
  mark_as_advanced(${CODING_CONV_PREFIX}_ClangTidy_OPTIONS)
  set(${CODING_CONV_PREFIX}_ClangTidy_FILES_RE
      "^.*\\\\.cc$$" "^.*\\\\.cpp$$" "^.*\\\\.cxx$$"
      CACHE STRING "List of regular expressions matching C/C++ filenames")
  set(${CODING_CONV_PREFIX}_ClangTidy_EXCLUDES_RE
      ".*/third[-_]parties/.*$$" ".*/third[-_]party/.*$$"
      CACHE STRING "list of regular expressions to exclude C/C++ files from formatting")
  set(${CODING_CONV_PREFIX}_ClangTidy_DEPENDENCIES
      ""
      CACHE STRING "list of CMake targets to build before formatting C/C++ code")
  mark_as_advanced(${CODING_CONV_PREFIX}_ClangTidy_OPTIONS ${CODING_CONV_PREFIX}_ClangTidy_FILES_RE
                   ${CODING_CONV_PREFIX}_ClangTidy_EXCLUDES_RE)
  execute_process(
    COMMAND git ls-files --error-unmatch .clang-tidy
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE is_clang_tidy_config_tracked
    ERROR_QUIET)
  if(NOT is_clang_tidy_config_tracked EQUAL 0)
    if(EXISTS ${PROJECT_SOURCE_DIR}/.clang-tidy.changes)
      execute_process(
        COMMAND ${PYTHON_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cpplib.py"
                merge-clang-tidy-config "${CMAKE_CURRENT_SOURCE_DIR}/.clang-tidy"
                "${PROJECT_SOURCE_DIR}/.clang-tidy.changes" "${PROJECT_SOURCE_DIR}/.clang-tidy")
    else()
      configure_file(.clang-tidy ${PROJECT_SOURCE_DIR} COPYONLY)
    endif()
  endif()
  unset(is_clang_tidy_config_tracked)

  set(clang_tidy_command_prefix
      ${PYTHON_EXECUTABLE}
      "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bbp-clang-tidy.py"
      -S
      "${CMAKE_SOURCE_DIR}"
      -B
      "${CMAKE_BINARY_DIR}"
      "--executable=${ClangTidy_EXECUTABLE}"
      --files-re
      "${${CODING_CONV_PREFIX}_ClangTidy_FILES_RE}"
      $<$<BOOL:${CODING_CONV_PREFIX}_FORMATTING_NO_SUBMODULES>:--git-modules>
      --excludes-re
      ${${CODING_CONV_PREFIX}_ClangTidy_EXCLUDES_RE}
      -p
      ${CMAKE_BINARY_DIR}/compile_commands.json
      --action
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

endfunction(bbp_enable_static_analysis)

bob_option(${CODING_CONV_PREFIX}_FORMATTING
           "Enable helpers to keep CMake and C++ code properly formatted" OFF)
bob_input(${CODING_CONV_PREFIX}_FORMATTING_ON "all" STRING
          "Specify changeset where formatting applies (see documentation for detailed information)")
bob_option(${CODING_CONV_PREFIX}_FORMATTING_CPP_CHANGES_ONLY
           "Only format the modified chunks, not the entire files" OFF)
bob_option(${CODING_CONV_PREFIX}_TEST_FORMATTING "Add CTest formatting test" OFF)
bob_option(${CODING_CONV_PREFIX}_FORMATTING_NO_SUBMODULES "Exclude git submodules from formatting" ON)
bob_option(${CODING_CONV_PREFIX}_CLANG_FORMAT "Enable helper to keep C++ code properly formatted" OFF)
bob_option(${CODING_CONV_PREFIX}_CMAKE_FORMAT "Enable helper to keep CMake code properly formatted"
           OFF)

bob_option(${CODING_CONV_PREFIX}_PRECOMMIT "Enable automatic checks before git commits" OFF)
bob_option(${CODING_CONV_PREFIX}_PRECOMMIT_REGEN "Force precommit hook regeneration" OFF)

bob_option(${CODING_CONV_PREFIX}_STATIC_ANALYSIS "Enable C++ static analysis during compilation" OFF)
bob_option(${CODING_CONV_PREFIX}_TEST_STATIC_ANALYSIS "Add CTest static analysis test" OFF)

if(${CODING_CONV_PREFIX}_CLANG_FORMAT OR ${CODING_CONV_PREFIX}_FORMATTING)
  bbp_enable_clang_formatting()
endif()

if(${CODING_CONV_PREFIX}_CMAKE_FORMAT OR ${CODING_CONV_PREFIX}_FORMATTING)
  bbp_enable_cmake_formatting()
endif()

if(${CODING_CONV_PREFIX}_PRECOMMIT)
  bbp_enable_precommit()
else(${CODING_CONV_PREFIX}_PRECOMMIT)
  bbp_disable_precommit()
endif(${CODING_CONV_PREFIX}_PRECOMMIT)

if(${CODING_CONV_PREFIX}_STATIC_ANALYSIS)
  cmake_minimum_required(VERSION 3.6)
  bbp_enable_static_analysis()
  set(CMAKE_CXX_CLANG_TIDY
      "${ClangTidy_EXECUTABLE}" -p "${CMAKE_BINARY_DIR}/compile_commands.json"
      ${${CODING_CONV_PREFIX}_ClangTidy_OPTIONS}
      PARENT_SCOPE)
endif(${CODING_CONV_PREFIX}_STATIC_ANALYSIS)
