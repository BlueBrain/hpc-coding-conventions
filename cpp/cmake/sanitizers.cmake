set(${CODING_CONV_PREFIX}_SANITIZERS
    ""
    CACHE STRING "Runtime sanitizers to enable. Possible values: undefined")
set(${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS
    ""
    CACHE
      STRING
      "Undefined behaviour sanitizer checks **not** to enable if ${CODING_CONV_PREFIX}_SANITIZERS contains 'undefined'"
)

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
# * ${CODING_CONV_PREFIX}_SANITIZER_LAUNCHER: command prefix that will pre-load the sanitizer
#   runtime libraries. This is useful if, for example, you want to load a sanitizer-instrumented
#   shared library (such as a Python module) from a non-instrumented binary (such as python).
# * ${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH: directory containing the sanitizer runtime
#   library. This is provided separately from the ENVIRONMENT variables to avoid assumptions about
#   the sanitizers being the only thing modifying LD_LIBRARY_PATH
#
# The caller is responsible for using these variables in a manner adapted to their application.
function(cpp_cc_enable_sanitizers)
  message(STATUS "Enabling sanitizers: ${${CODING_CONV_PREFIX}_SANITIZERS}")
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
  # Compile with -g and -fno-omit-frame-pointer to get proper debug information in your binary. Run
  # your program with environment variable UBSAN_OPTIONS=print_stacktrace=1. Make sure
  # llvm-symbolizer binary is in PATH.
  if("undefined" IN_LIST ${CODING_CONV_PREFIX}_SANITIZERS)
    if(NOT "${${CODING_CONV_PREFIX}_SANITIZERS}" STREQUAL "undefined")
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
    # Use the shared library version of the sanitizer runtime so that we can LD_PRELOAD it when
    # launching via Python and so on
    set(compiler_flags -g -fno-omit-frame-pointer -shared-libsan)
    foreach(undefined_check ${undefined_checks})
      list(APPEND compiler_flags -fsanitize=${undefined_check})
    endforeach()
    message(STATUS "UBSan compiler flags: ${compiler_flags}")
    # Figure out where the runtime library lives
    execute_process(
      COMMAND
        ${CMAKE_CXX_COMPILER}
        -print-file-name=${CMAKE_SHARED_LIBRARY_PREFIX}clang_rt.ubsan_standalone-${CMAKE_SYSTEM_PROCESSOR}${CMAKE_SHARED_LIBRARY_SUFFIX}
      RESULT_VARIABLE clang_status
      OUTPUT_VARIABLE clang_stdout
      ERROR_VARIABLE clang_stderr
      OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_STRIP_TRAILING_WHITESPACE)
    if(${clang_status})
      message(
        FATAL_ERROR
          "Failed to find UBSan runtime library (stdout: ${clang_stdout}, stderr: ${clang_stderr})")
    endif()
    set(runtime_library "${clang_stdout}")
    get_filename_component(runtime_library_directory "${runtime_library}" DIRECTORY)
    message(STATUS "UBSan runtime library: ${runtime_library}")
    message(STATUS "UBSan runtime library directory: ${runtime_library_directory}")
    # TODO: llvm-symbolizer?
    set(${CODING_CONV_PREFIX}_SANITIZER_COMPILER_FLAGS
        "${compiler_flags}"
        PARENT_SCOPE)
    set(${CODING_CONV_PREFIX}_SANITIZER_ENABLE_ENVIRONMENT
        "UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1"
        PARENT_SCOPE)
    set(${CODING_CONV_PREFIX}_SANITIZER_DISABLE_ENVIRONMENT
        "UBSAN_OPTIONS=print_stacktrace=0:halt_on_error=0"
        PARENT_SCOPE)
    set(${CODING_CONV_PREFIX}_SANITIZER_LAUNCHER
        ""
        PARENT_SCOPE)
    set(${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH
        "${runtime_library_directory}"
        PARENT_SCOPE)
  else()
    message(FATAL_ERROR "${${CODING_CONV_PREFIX}_SANITIZERS} sanitizers not yet supported")
  endif()
endfunction(cpp_cc_enable_sanitizers)

# Helper function that modifies a test created by add_test to have the required environment
# variables set for successful execution when sanitizers are enabled
#
# cpp_cc_set_sanitizer_env(TEST [<test1> ...])
#
# Arguments:
#
# * TEST: list of test names to modify
function(cpp_cc_set_sanitizer_env)
  cmake_parse_arguments("" "" "" "TEST" ${ARGN})
  foreach(test ${_TEST})
    if(${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH)
      message(STATUS "Setting path to sanitizer runtime for test: ${test}")
      # If LD_LIBRARY_PATH is already set, prepend our path to it. If it's not, set it to our path,
      # followed by $ENV{LD_LIBRARY_PATH}
      get_test_property(${test} ENVIRONMENT env)
      set(seen_ld_library_path OFF)
      if(NOT "${env}" STREQUAL "NOTFOUND")
        foreach(env_var ${env})
          if(env_var MATCHES "^LD_LIBRARY_PATH=(.*)$")
            list(APPEND new_env
                 "LD_LIBRARY_PATH=${${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH}:${CMAKE_MATCH_1}")
            set(seen_ld_library_path ON)
          else()
            list(APPEND new_env "${env_var}")
          endif()
        endforeach()
      endif()
      if(NOT seen_ld_library_path)
        list(
          APPEND new_env
          "LD_LIBRARY_PATH=${${CODING_CONV_PREFIX}_SANITIZER_LIBRARY_PATH}:$ENV{LD_LIBRARY_PATH}")
      endif()
      # This should be sanitizer-specific stuff like UBSAN_OPTIONS, so we don't need to worry about
      # merging it with an existing value.
      list(APPEND new_env "${${CODING_CONV_PREFIX}_SANITIZER_ENABLE_ENVIRONMENT}")
      set_tests_properties(${test} PROPERTIES ENVIRONMENT "${new_env}")
    endif()
  endforeach()
endfunction(cpp_cc_set_sanitizer_env)

if(${CODING_CONV_PREFIX}_SANITIZERS)
  cpp_cc_enable_sanitizers()
endif()
