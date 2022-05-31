set(${CODING_CONV_PREFIX}_SANITIZERS
    ""
    CACHE STRING "Runtime sanitizers to enable. Possible values: undefined")
set(${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS
    ""
    CACHE STRING "Undefined behaviour sanitizer checks **not** to enable if ${CODING_CONV_PREFIX}_SANITIZERS contains undefined")
  
# Assemble compiler flags, environment variables and command prefixes needed to
# enable runtime sanitizers (address, leak, undefined behaviour, thread,
# memory...)
#
# cpp_cc_enable_sanitizers()
# 
# Sets:
# ${CODING_CONV_PREFIX}_SANITIZER_COMPILER_FLAGS: compiler flags that should be
# passed to the compiler and linker.
# ${CODING_CONV_PREFIX}_SANITIZER_ENABLE_ENVIRONMENT: environment variables that
# should be set to **enable** sanitizers at runtime.
# ${CODING_CONV_PREFIX}_SANITIZER_DISABLE_ENVIRONMENT: environment variables that
# should be set to **disable** sanitizers at runtime. This might be useful if,
# for example, some part of the instrumented application is used during the
# build and you don't want memory leaks to cause build failures.
# ${CODING_CONV_PREFIX}_SANITIZER_LAUNCHER: command prefix that will pre-load
# the sanitizer runtime libraries. This is useful if, for example, you want to
# load a sanitizer-instrumented shared library (such as a Python module) from a
# non-instrumented binary (such as python).
#
# The caller is responsible for using these variables in a manner adapted to
# their application.
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
  # Compile with -g and -fno-omit-frame-pointer to get proper debug information in your binary.
  # Run your program with environment variable UBSAN_OPTIONS=print_stacktrace=1.
  # Make sure llvm-symbolizer binary is in PATH.
  if("undefined" IN_LIST ${CODING_CONV_PREFIX}_SANITIZERS)
    if(NOT "${${CODING_CONV_PREFIX}_SANITIZERS}" STREQUAL "undefined")
      message(FATAL_ERROR "Enabling the undefined behaviour sanitizer at the same time as other sanitizers is not currently supported (got: ${${CODING_CONV_PREFIX}_SANITIZERS})")
    endif()
    # Enable the undefined behaviour sanitizer
    if(${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS)
      message(STATUS "Disabling UBSan checks: ${${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS}")
      list(REMOVE_ITEM undefined_checks ${${CODING_CONV_PREFIX}_SANITIZERS_UNDEFINED_EXCLUSIONS})
    endif()
    # Use the shared library version of the sanitizer runtime so that we can
    # LD_PRELOAD it when launching via Python and so on
    set(compiler_flags -g -fno-omit-frame-pointer -shared-libsan)
    foreach(undefined_check ${undefined_checks})
      list(APPEND compiler_flags -fsanitize=${undefined_check})
    endforeach()
    message(STATUS "UBSan compiler flags: ${compiler_flags}")
    # Figure out where the runtime library lives
    execute_process(COMMAND ${CMAKE_CXX_COMPILER} -print-file-name=${CMAKE_SHARED_LIBRARY_PREFIX}clang_rt.ubsan_standalone-${CMAKE_SYSTEM_PROCESSOR}${CMAKE_SHARED_LIBRARY_SUFFIX}
                    RESULT_VARIABLE clang_status
                    OUTPUT_VARIABLE clang_stdout
                    ERROR_VARIABLE clang_stderr
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_STRIP_TRAILING_WHITESPACE)
    if(${clang_status})
      message(FATAL_ERROR "Failed to find UBSan runtime library (stdout: ${clang_stdout}, stderr: ${clang_stderr})")
    endif()
    set(runtime_library "${clang_stdout}")
    get_filename_component(runtime_library_directory "${runtime_library}" DIRECTORY)
    message(STATUS "UBSan runtime library: ${runtime_library}")
    message(STATUS "UBSan runtime library directory: ${runtime_library_directory}")
# So the runtime can be found during the build. Do this before CMake so that if CMake reads LD_LIBRARY_PATH and saves it somewhere then it includes the path.
#export LD_LIBRARY_PATH=${SANITIZER_RUNTIME_DIR}${SANITIZER_RUNTIME_DIR:+:}${LD_LIBRARY_PATH}
# NEURON forces Python stuff to be built with the same compiler as NEURON itself.
# This causes problems, because Python wants to build things with the same compiler as Python.
# By default we get the worst of all worlds: NEURON makes Python stuff get compiled with Clang, Python makes it get linked with GCC.
# These two lines make us do things the NEURON way :shrug:
#export LDCSHARED="$(command -v clang) -shared -pthread"
#export LDCXXSHARED="$(command -v clang++) -shared -pthread"
#COMPILER_FLAGS="-fsanitize=undefined -fsanitize=float-divide-by-zero -fno-omit-frame-pointer -shared-libsan -fsanitize=implicit-conversion -fsanitize=local-bounds -fsanitize=nullability-arg -fsanitize=nullability-assign -fsanitize=nullability-return"
#COMPILER_FLAGS=""
#-DNMODL_EXTRA_CXX_FLAGS="${COMPILER_FLAGS}" \


  else()
  endif()
endfunction(cpp_cc_enable_sanitizers)

if(${CODING_CONV_PREFIX}_SANITIZERS)
  cpp_cc_enable_sanitizers()
endif()