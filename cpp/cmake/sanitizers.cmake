set(${CODING_CONV_PREFIX}_SANITIZERS
    ""
    CACHE STRING "Runtime sanitizers to enable. Possible values: undefined")
set(${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS
    ""
    CACHE
      STRING
      "Undefined behaviour sanitizer checks **not** to enable if ${CODING_CONV_PREFIX}_SANITIZERS contains 'undefined'"
)

# Find the path of a sanitizer runtime library. This is mainly intended for internal use.
#
# cpp_cc_find_sanitizer_runtime(NAME [<name>] OUTPUT [<output variable>])
function(cpp_cc_find_sanitizer_runtime)
  cmake_parse_arguments("" "" "NAME;OUTPUT" "" ${ARGN})
  execute_process(
    COMMAND
      ${CMAKE_CXX_COMPILER}
      -print-file-name=${CMAKE_SHARED_LIBRARY_PREFIX}clang_rt.${_NAME}-${CMAKE_SYSTEM_PROCESSOR}${CMAKE_SHARED_LIBRARY_SUFFIX}
    RESULT_VARIABLE clang_status
    OUTPUT_VARIABLE runtime_library
    ERROR_VARIABLE clang_stderr
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_STRIP_TRAILING_WHITESPACE)
  if(${clang_status})
    message(
      FATAL_ERROR
        "Failed to find ${_NAME} runtime library (stdout: ${runtime_library}, stderr: ${clang_stderr})"
    )
  endif()
  message(STATUS "Sanitizer runtime library: ${runtime_library}")
  set(${_OUTPUT}
      "${runtime_library}"
      PARENT_SCOPE)
endfunction()

# Assemble compiler flags, environment variables and command prefixes needed to enable runtime
# sanitizers (address, leak, undefined behaviour, thread, memory...)
#
# cpp_cc_enable_sanitizers()
#
# Sets:
#
# * ${CODING_CONV_PREFIX}_SANITIZER_COMPILER_FLAGS: compiler flags that should be passed to the
#   compiler and linker.
# * ${CODING_CONV_PREFIX}_SANITIZER_ENABLE_ENVIRONMENT: environment variables that should be set to
#   **enable** sanitizers at runtime.
# * ${CODING_CONV_PREFIX}_SANITIZER_DISABLE_ENVIRONMENT: environment variables that should be set to
#   **disable** sanitizers at runtime. This might be useful if, for example, some part of the
#   instrumented application is used during the build and you don't want memory leaks to cause build
#   failures.
# * ${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH: the sanitizer runtime library. This sometimes
#   needs to be added to LD_PRELOAD.
# * ${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_DIR: the directory where the sanitizer runtime library
#   sits. This is provided separately from the ENVIRONMENT variables to avoid assumptions about the
#   sanitizers being the only thing modifying LD_LIBRARY_PATH
#
# The caller is responsible for using these variables in a manner adapted to their application.
function(cpp_cc_enable_sanitizers)
  message(STATUS "Enabling sanitizers: ${${CODING_CONV_PREFIX}_SANITIZERS}")
  # comma-separated string -> CMake list
  string(REPLACE "," ";" sanitizers "${${CODING_CONV_PREFIX}_SANITIZERS}")
  # known exclusions from this list: objc-cast
  set(undefined_checks
      alignment
      bool
      builtin
      array-bounds
      local-bounds
      enum
      float-cast-overflow
      float-divide-by-zero
      function
      implicit-unsigned-integer-truncation
      implicit-signed-integer-truncation
      implicit-integer-sign-change
      integer-divide-by-zero
      nonnull-attribute
      null
      nullability-arg
      nullability-assign
      nullability-return
      object-size
      pointer-overflow
      return
      returns-nonnull-attribute
      shift-base
      shift-exponent
      unsigned-shift-base
      signed-integer-overflow
      unreachable
      unsigned-integer-overflow
      vla-bound
      vptr)
  # Use the shared library version of the sanitizer runtime so that we can LD_PRELOAD it when
  # launching via Python and so on
  set(compiler_flags -g -fno-omit-frame-pointer -shared-libsan)
  if("undefined" IN_LIST sanitizers)
    if(NOT sanitizers STREQUAL "undefined")
      message(
        FATAL_ERROR
          "Enabling the undefined behaviour sanitizer at the same time as other sanitizers is not currently supported (got: ${${CODING_CONV_PREFIX}_SANITIZERS})"
      )
    endif()
    # Enable the undefined behaviour sanitizer
    if(${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS)
      message(
        STATUS "Disabling UBSan checks: ${${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS}")
      list(REMOVE_ITEM undefined_checks ${${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS})
    endif()
    foreach(undefined_check ${undefined_checks})
      list(APPEND compiler_flags -fsanitize=${undefined_check})
    endforeach()
    string(JOIN " " compiler_flags_str ${compiler_flags})
    message(STATUS "UBSan compiler flags: ${compiler_flags_str}")
    # Figure out where the runtime library lives
    cpp_cc_find_sanitizer_runtime(NAME ubsan_standalone OUTPUT runtime_library)
    # TODO: llvm-symbolizer? ensure it's in the path via these environment variables? TODO:
    # standardised way of using exclusions/suppressions for the different sanitizers
    if(EXISTS "${PROJECT_SOURCE_DIR}/.sanitizers/undefined.supp")
      set(ubsan_opts "suppressions=${PROJECT_SOURCE_DIR}/.sanitizers/undefined.supp:")
    endif()
    set(enable_env "UBSAN_OPTIONS=${ubsan_opts}print_stacktrace=1:halt_on_error=1")
    set(disable_env "UBSAN_OPTIONS=${ubsan_opts}print_stacktrace=0:halt_on_error=0")
  elseif("address" IN_LIST sanitizers)
    list(APPEND compiler_flags -fsanitize=address -fsanitize-address-use-after-scope)
    # Figure out where the runtime library lives
    cpp_cc_find_sanitizer_runtime(NAME asan OUTPUT runtime_library)
    set(enable_env ASAN_OPTIONS=check_initialization_order=1:detect_stack_use_after_return=1)
    if("leak" IN_LIST sanitizers)
      string(APPEND enable_env ":detect_leaks=1")
      list(APPEND enable_env PYTHONMALLOC=malloc)
      if(EXISTS "${PROJECT_SOURCE_DIR}/.sanitizers/leak.supp")
        list(APPEND enable_env
             "LSAN_OPTIONS=suppressions=${PROJECT_SOURCE_DIR}/.sanitizers/leak.supp")
      endif()
    else()
      string(APPEND enable_env ":detect_leaks=0")
    endif()
    set(disable_env ASAN_OPTIONS=detect_leaks=0)
    # TODO: ASAN_SYMBOLIZER_PATH
  elseif("leak" IN_LIST sanitizers)
    message(FATAL_ERROR "LSan not yet supported in standalone mode")
  else()
    message(FATAL_ERROR "${sanitizers} sanitizers not yet supported")
  endif()
  get_filename_component(runtime_library_directory "${runtime_library}" DIRECTORY)
  set(${CODING_CONV_PREFIX}_SANITIZER_COMPILER_FLAGS
      "${compiler_flags}"
      PARENT_SCOPE)
  set(${CODING_CONV_PREFIX}_SANITIZER_ENABLE_ENVIRONMENT
      "${enable_env}"
      PARENT_SCOPE)
  set(${CODING_CONV_PREFIX}_SANITIZER_DISABLE_ENVIRONMENT
      "${disable_env}"
      PARENT_SCOPE)
  set(${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_DIR
      "${runtime_library_directory}"
      PARENT_SCOPE)
  set(${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH
      "${runtime_library}"
      PARENT_SCOPE)
endfunction(cpp_cc_enable_sanitizers)

# Helper function that modifies a test created by add_test to have the required environment
# variables set for successful execution when sanitizers are enabled
#
# cpp_cc_set_sanitizer_env(TEST [<test1> ...] [PRELOAD])
#
# Arguments:
#
# * TEST: list of test names to modify
# * PRELOAD: if passed, LD_PRELOAD will be set to the sanitizer runtime library and LD_LIBRARY_PATH
#   will not be modified
function(cpp_cc_set_sanitizer_env)
  cmake_parse_arguments("" "PRELOAD" "" "TEST" ${ARGN})
  foreach(test ${_TEST})
    if(_PRELOAD)
      set_property(
        TEST ${test}
        APPEND
        PROPERTY ENVIRONMENT LD_PRELOAD=${${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH})
    elseif(${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_DIR)
      message(STATUS "Setting path to sanitizer runtime for test: ${test}")
      # If LD_LIBRARY_PATH is already set, prepend our path to it. If it's not, set it to our path,
      # followed by $ENV{LD_LIBRARY_PATH}
      get_test_property(${test} ENVIRONMENT env)
      set(seen_ld_library_path OFF)
      if(NOT "${env}" STREQUAL "NOTFOUND")
        foreach(env_var ${env})
          if(env_var MATCHES "^LD_LIBRARY_PATH=(.*)$")
            list(APPEND new_env
                 "LD_LIBRARY_PATH=${${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_DIR}:${CMAKE_MATCH_1}")
            set(seen_ld_library_path ON)
          else()
            list(APPEND new_env "${env_var}")
          endif()
        endforeach()
      endif()
      if(NOT seen_ld_library_path)
        list(APPEND new_env
             "LD_LIBRARY_PATH=${${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_DIR}:$ENV{LD_LIBRARY_PATH}")
      endif()
      set_tests_properties(${test} PROPERTIES ENVIRONMENT "${new_env}")
    endif()
    # This should be sanitizer-specific stuff like UBSAN_OPTIONS, so we don't need to worry about
    # merging it with an existing value.
    set_property(
      TEST ${test}
      APPEND
      PROPERTY ENVIRONMENT ${${CODING_CONV_PREFIX}_SANITIZER_ENABLE_ENVIRONMENT})
  endforeach()
endfunction(cpp_cc_set_sanitizer_env)

if(${CODING_CONV_PREFIX}_SANITIZERS)
  cpp_cc_enable_sanitizers()
endif()
