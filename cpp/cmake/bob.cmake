function(bob_always_full_rpath)
  # CMake RPATH "always full" configuration, see:
  # https://cmake.org/Wiki/CMake_RPATH_handling#Always_full_RPATH use, i.e. don't skip the full
  # RPATH for the build tree
  set(CMAKE_SKIP_BUILD_RPATH
      False
      PARENT_SCOPE)
  # when building, don't use the install RPATH already (but later on when installing)
  set(CMAKE_BUILD_WITH_INSTALL_RPATH
      False
      PARENT_SCOPE)
  # the RPATH to be used when installing, but only if it's not a system directory
  list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
  if("${isSystemDir}" STREQUAL "-1")
    set(CMAKE_INSTALL_RPATH
        "${CMAKE_INSTALL_PREFIX}/lib"
        PARENT_SCOPE)
  endif()
  # add the automatically determined parts of the RPATH which point to directories outside the build
  # tree to the install RPATH
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH
      True
      PARENT_SCOPE)
endfunction(bob_always_full_rpath)

function(bob_cmake_arg2 var type default)
  if(NOT ${var} STREQUAL "${default}")
    if(${CODING_CONV_PREFIX}_CMAKE_ARGS)
      set(sep " ")
    else()
      set(sep "")
    endif()
    set(${CODING_CONV_PREFIX}_CMAKE_ARGS
        "${${CODING_CONV_PREFIX}_CMAKE_ARGS}${sep}-D${var}:${type}=\"${${var}}\""
        CACHE STRING "CMake arguments that would replicate this configuration" FORCE)
  endif()
endfunction()

function(bob_cmake_arg var type default)
  message(STATUS "${var}: ${${var}}")
  bob_cmake_arg2("${var}" "${type}" "${default}")
endfunction()

function(bob_option var desc default)
  option(${var} "${desc}" "${default}")
  bob_cmake_arg(${var} BOOL "${default}")
endfunction()

function(bob_input var default type desc)
  set(${var}
      "${default}"
      CACHE ${type} "${desc}")
  bob_cmake_arg(${var} ${type} "${default}")
endfunction()

macro(bob_begin_package)
  set(${CODING_CONV_PREFIX}_CMAKE_ARGS
      ""
      CACHE STRING "CMake arguments that would replicate this configuration" FORCE)
  message(STATUS "CMAKE_VERSION: ${CMAKE_VERSION}")
  if(${CODING_CONV_PREFIX}_VERSION)
    message(STATUS "${CODING_CONV_PREFIX}_VERSION: ${${CODING_CONV_PREFIX}_VERSION}")
  endif()
  option(USE_XSDK_DEFAULTS "enable the XDSK v0.3.0 default configuration" OFF)
  bob_cmake_arg(USE_XSDK_DEFAULTS BOOL OFF)
  if(NOT MEMORYCHECK_COMMAND)
    # try to force BUILD_TESTING to be OFF by default if memory check is not activated
    set(BUILD_TESTING
        OFF
        CACHE BOOL "Build and run tests")
  endif()
  include(CTest)
  enable_testing()
  option(BUILD_SHARED_LIBS "Build shared libraries" ON)
  # If not building shared libs, then prefer static dependency libs
  if(NOT BUILD_SHARED_LIBS)
    set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so" ".dylib")
  endif()
  if(USE_XSDK_DEFAULTS)
    string(STRIP "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE)
    if(NOT CMAKE_BUILD_TYPE)
      set(CMAKE_BUILD_TYPE "Debug")
    endif()
    bob_cmake_arg(CMAKE_BUILD_TYPE STRING "")
  endif()
  bob_always_full_rpath()
  bob_cmake_arg(BUILD_TESTING BOOL OFF)
  bob_cmake_arg(BUILD_SHARED_LIBS BOOL ON)
  bob_cmake_arg(CMAKE_INSTALL_PREFIX PATH "")
  option(${CODING_CONV_PREFIX}_NORMAL_CXX_FLAGS
         "Allow CMAKE_CXX_FLAGS to follow \"normal\" CMake behavior" ${USE_XSDK_DEFAULTS})
endmacro(bob_begin_package)

function(bob_get_commit)
  execute_process(
    COMMAND git rev-parse HEAD
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE NO_SHA1
    OUTPUT_VARIABLE SHA1
    ERROR_VARIABLE SHA1_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NO_SHA1)
    message(WARNING "bob_get_commit: no Git hash!\n" ${SHA1_ERROR})
  else()
    set(${CODING_CONV_PREFIX}_COMMIT
        "${SHA1}"
        PARENT_SCOPE)
  endif()
endfunction(bob_get_commit)

function(bob_get_semver)
  execute_process(
    COMMAND git describe --exact-match HEAD
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    RESULT_VARIABLE NOT_TAG
    OUTPUT_VARIABLE TAG_NAME
    ERROR_VARIABLE TAG_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT_TAG)
    if(${CODING_CONV_PREFIX}_VERSION)
      set(SEMVER ${${CODING_CONV_PREFIX}_VERSION})
      execute_process(
        COMMAND git log -1 --format=%h
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        RESULT_VARIABLE NO_SHA1
        OUTPUT_VARIABLE SHORT_SHA1
        ERROR_VARIABLE SHA1_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      if(NO_SHA1)
        message(WARNING "bob_get_semver no Git hash!\n" ${SHA1_ERROR})
      else()
        set(SEMVER "${SEMVER}-sha.${SHORT_SHA1}")
      endif()
    else()
      message(FATAL_ERROR "bob_get_semver needs either ${CODING_CONV_PREFIX}_VERSION or a Git tag\n"
                          ${TAG_ERROR})
    endif()
  else()
    if(TAG_NAME MATCHES "^v([0-9]+[.])?([0-9]+[.])?([0-9]+)$")
      string(SUBSTRING "${TAG_NAME}" 1 -1 SEMVER)
      if(${CODING_CONV_PREFIX}_VERSION AND (NOT (SEMVER VERSION_EQUAL ${CODING_CONV_PREFIX}_VERSION)
                                           ))
        message(
          FATAL_ERROR
            "bob_get_semver: tag is ${TAG_NAME} but ${CODING_CONV_PREFIX}_VERSION=${${CODING_CONV_PREFIX}_VERSION} !"
        )
      endif()
    else()
      if(${CODING_CONV_PREFIX}_VERSION)
        set(SEMVER "${${CODING_CONV_PREFIX}_VERSION}-tag.${TAG_NAME}")
      else()
        message(
          FATAL_ERROR
            "bob_get_semver needs either ${CODING_CONV_PREFIX}_VERSION or a Git tag of the form v1.2.3"
        )
      endif()
    endif()
  endif()
  if(${CODING_CONV_PREFIX}_KEY_BOOLS)
    set(SEMVER "${SEMVER}+")
    foreach(KEY_BOOL IN LISTS ${CODING_CONV_PREFIX}_KEY_BOOLS)
      if(${KEY_BOOL})
        set(SEMVER "${SEMVER}1")
      else()
        set(SEMVER "${SEMVER}0")
      endif()
    endforeach()
  endif()
  set(${CODING_CONV_PREFIX}_SEMVER
      "${SEMVER}"
      PARENT_SCOPE)
  message(STATUS "${CODING_CONV_PREFIX}_SEMVER = ${SEMVER}")
endfunction(bob_get_semver)

function(bob_cxx_pedantic_flags)
  # Append to variable CMAKE_CXX_FLAGS the set of warnings recommended for development, based on
  # compiler family and version.
  #
  # Flags are appended to a custom variable instead of CMAKE_CXX_FLAGS if passed in parameter, for
  # instance: bob_cxx_pedantic_flags(PEDANTIC_FLAGS)
  #
  set(flags "")
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(flags "${flags} -Werror -Weverything")
    set(flags "${flags} -Wno-disabled-macro-expansion")
    set(flags "${flags} -Wno-documentation-unknown-command")
    set(flags "${flags} -Wno-padded")
    set(flags "${flags} -Wno-unused-member-function")
    if(APPLE)
      set(flags "${flags} -Wno-undef")
      if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "8.0.0")
        set(flags "${flags} -fcomment-block-commands=file")
      endif()
    else()
      if(CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "5.0.0")
        set(flags "${flags} -fcomment-block-commands=file")
      endif()
      if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "5.0.0")
        set(flags "${flags} -fcomment-block-commands=file")
      endif()
    endif()
  elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
    set(flags "${flags} -Wall")
    set(flags "${flags} -Wcast-align")
    set(flags "${flags} -Wconversion")
    set(flags "${flags} -Wdouble-promotion")
    set(flags "${flags} -Werror")
    set(flags "${flags} -Wextra")
    set(flags "${flags} -Wformat=2")
    set(flags "${flags} -Wnon-virtual-dtor")
    set(flags "${flags} -Wold-style-cast")
    set(flags "${flags} -Woverloaded-virtual")
    set(flags "${flags} -Wshadow")
    set(flags "${flags} -Wsign-conversion")
    set(flags "${flags} -Wunused")
    set(flags "${flags} -Wuseless-cast")
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "6.0")
      set(flags "${flags} -Wduplicated-cond")
      set(flags "${flags} -Wmisleading-indentation")
      set(flags "${flags} -Wnull-dereference")
    endif()
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "7.0")
      set(flags "${flags} -Wduplicated-branches")
      set(flags "${flags} -Wlogical-op")
      set(flags "${flags} -Wrestrict")
    endif()
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "8.0")
      # set(flags "${flags} -Wclass-memaccess") set(flags "${flags} -Wstringop-truncation")
    endif()
  elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Intel")

  else()
    message(WARNING "Unexpected compiler type ${CMAKE_CXX_COMPILER_ID}")
  endif()

  if(ARGC EQUAL 0)
    set(CMAKE_CXX_FLAGS
        "${CMAKE_CXX_FLAGS} ${flags}"
        PARENT_SCOPE)
  else()
    set(${ARGV0}
        "${${ARGV0}} ${flags}"
        PARENT_SCOPE)
  endif()
endfunction(bob_cxx_pedantic_flags)

function(bob_begin_cxx_flags)
  if(${CODING_CONV_PREFIX}_NORMAL_CXX_FLAGS)
    set(BOB_CMAKE_CXX_FLAGS
        "${CMAKE_CXX_FLAGS}"
        PARENT_SCOPE)
    bob_cmake_arg2(CMAKE_CXX_FLAGS STRING "")
  else()
    string(STRIP "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE)
    if(CMAKE_BUILD_TYPE)
      message(FATAL_ERROR "can't set CMAKE_BUILD_TYPE and use bob_*_cxx_flags")
    endif()
    option(${CODING_CONV_PREFIX}_CXX_OPTIMIZE "Compile C++ with optimization" ON)
    option(${CODING_CONV_PREFIX}_CXX_SYMBOLS "Compile C++ with debug symbols" ON)
    option(${CODING_CONV_PREFIX}_CXX_WARNINGS "Compile C++ with warnings" ON)
    bob_cmake_arg(${CODING_CONV_PREFIX}_CXX_OPTIMIZE BOOL ON)
    bob_cmake_arg(${CODING_CONV_PREFIX}_CXX_SYMBOLS BOOL ON)
    set(${CODING_CONV_PREFIX}_ARCH
        ""
        CACHE STRING "Argument to -march or -arch")
    bob_cmake_arg(${CODING_CONV_PREFIX}_ARCH STRING "native")
    # CDash's simple output parser interprets the variable name WARNINGS as a warning...
    message(STATUS "${CODING_CONV_PREFIX}_CXX_W**NINGS: ${${CODING_CONV_PREFIX}_CXX_WARNINGS}")
    bob_cmake_arg2(${CODING_CONV_PREFIX}_CXX_WARNINGS BOOL ON)
    set(FLAGS "")
    if(${CODING_CONV_PREFIX}_CXX_OPTIMIZE)
      set(FLAGS "${FLAGS} -O3 -DNDEBUG")
      if(${CODING_CONV_PREFIX}_ARCH)
        if(${CODING_CONV_PREFIX}_USE_CUDA)
          set(FLAGS "${FLAGS} -arch=${${CODING_CONV_PREFIX}_ARCH}")
        else()
          set(FLAGS "${FLAGS} -march=${${CODING_CONV_PREFIX}_ARCH}")
        endif()
      endif()
    else()
      set(FLAGS "${FLAGS} -O0")
    endif()
    if(${CODING_CONV_PREFIX}_CXX_SYMBOLS)
      set(FLAGS "${FLAGS} -g")
    endif()
    # -----------
    if(${CODING_CONV_PREFIX}_CXX_WARNINGS)
      bob_cxx_pedantic_flags(FLAGS)
    endif()
    set(BOB_CMAKE_CXX_FLAGS
        "${FLAGS}"
        PARENT_SCOPE)
  endif()
endfunction(bob_begin_cxx_flags)

macro(bob_cxx_standard_flags standard)
  if(NOT standard VERSION_EQUAL 98 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    if(${CODING_CONV_PREFIX}_CXX_WARNINGS)
      set(BOB_CMAKE_CXX_FLAGS
          "${BOB_CMAKE_CXX_FLAGS} -Wno-c++98-compat-pedantic -Wno-c++98-compat"
          PARENT_SCOPE)
    endif()
  endif()
  set(CMAKE_CXX_STANDARD
      "${standard}"
      PARENT_SCOPE)
  set(CXX_STANDARD_REQUIRED
      "TRUE"
      PARENT_SCOPE)
  set(CMAKE_CXX_EXTENSIONS
      "NO"
      PARENT_SCOPE)
endmacro(bob_cxx_standard_flags standard)

function(bob_cxx11_flags)
  bob_cxx_standard_flags(11)
endfunction(bob_cxx11_flags)

function(bob_cxx14_flags)
  bob_cxx_standard_flags(14)
endfunction(bob_cxx14_flags)

function(bob_cxx17_flags)
  bob_cxx_standard_flags(17)
endfunction(bob_cxx17_flags)

function(bob_cxx20_flags)
  bob_cxx_standard_flags(20)
endfunction(bob_cxx20_flags)

function(bob_end_cxx_flags)
  if(${CODING_CONV_PREFIX}_NORMAL_CXX_FLAGS)
    message(STATUS "CMAKE_CXX_FLAGS: ${BOB_CMAKE_CXX_FLAGS}")
    set(CMAKE_CXX_FLAGS
        "${BOB_CMAKE_CXX_FLAGS}"
        PARENT_SCOPE)
  else()
    set(${CODING_CONV_PREFIX}_CXX_FLAGS
        ""
        CACHE STRING "Override all C++ compiler flags")
    bob_cmake_arg(${CODING_CONV_PREFIX}_CXX_FLAGS STRING "")
    set(${CODING_CONV_PREFIX}_EXTRA_CXX_FLAGS
        ""
        CACHE STRING "Extra C++ compiler flags")
    bob_cmake_arg(${CODING_CONV_PREFIX}_EXTRA_CXX_FLAGS STRING "")
    if(${CODING_CONV_PREFIX}_CXX_FLAGS)
      set(FLAGS "${${CODING_CONV_PREFIX}_CXX_FLAGS}")
    else()
      set(FLAGS
          "${CMAKE_CXX_FLAGS} ${BOB_CMAKE_CXX_FLAGS} ${${CODING_CONV_PREFIX}_EXTRA_CXX_FLAGS}")
    endif()
    message(STATUS "CMAKE_CXX_FLAGS: ${FLAGS}")
    set(CMAKE_CXX_FLAGS
        "${FLAGS}"
        PARENT_SCOPE)
  endif()
endfunction(bob_end_cxx_flags)

macro(bob_add_dependency)
  set(options PUBLIC PRIVATE)
  set(oneValueArgs NAME)
  set(multiValueArgs COMPONENTS TARGETS INCLUDE_DIR_VARS LIBRARY_VARS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(NOT ARG_NAME)
    message(FATAL_ERROR "bob_add_dependency: no NAME argument given")
  endif()
  if(ARG_PUBLIC AND ARG_PRIVATE)
    message(FATAL_ERROR "bob_add_dependency: can't specify both PUBLIC and PRIVATE")
  endif()
  if(ARG_COMPONENTS)
    set(ARG_COMPONENTS COMPONENTS ${ARG_COMPONENTS})
  endif()
  if(USE_XSDK_DEFAULTS)
    option(TPL_ENABLE_${ARG_NAME} "Whether to use ${ARG_NAME}"
           "${${CODING_CONV_PREFIX}_USE_${ARG_NAME}_DEFAULT}")
    bob_cmake_arg(TPL_ENABLE_${ARG_NAME} BOOL "${${CODING_CONV_PREFIX}_USE_${ARG_NAME}_DEFAULT}")
    set(${CODING_CONV_PREFIX}_USE_${ARG_NAME} "${TPL_ENABLE_${ARG_NAME}}")
    if(TPL_ENABLE_${ARG_NAME})
      set(TPL_${ARG_NAME}_LIBRARIES
          ""
          CACHE STRING "${ARG_NAME} libraries")
      bob_cmake_arg(TPL_${ARG_NAME}_LIBRARIES STRING "")
      set(TPL_${ARG_NAME}_INCLUDE_DIRS
          ""
          CACHE STRING "${ARG_NAME} include directories")
      bob_cmake_arg(TPL_${ARG_NAME}_INCLUDE_DIRS STRING "")
      set(tgt "${CODING_CONV_PREFIX}-${ARG_NAME}")
      add_library(${tgt} INTERFACE)
      target_include_directories(${tgt} INTERFACE "${TPL_${ARG_NAME}_INCLUDE_DIRS}")
      target_link_libraries(${tgt} INTERFACE "${TPL_${ARG_NAME}_LIBRARIES}")
    endif()
  else()
    option(${CODING_CONV_PREFIX}_USE_${ARG_NAME} "Whether to use ${ARG_NAME}"
           ${${CODING_CONV_PREFIX}_USE_${ARG_NAME}_DEFAULT})
    bob_cmake_arg(${CODING_CONV_PREFIX}_USE_${ARG_NAME} BOOL
                  "${${CODING_CONV_PREFIX}_USE_${ARG_NAME}_DEFAULT}")
    if(${CODING_CONV_PREFIX}_USE_${ARG_NAME})
      set(${ARG_NAME}_PREFIX
          "${${ARG_NAME}_PREFIX_DEFAULT}"
          CACHE PATH "${ARG_NAME} install directory")
      bob_cmake_arg(${ARG_NAME}_PREFIX PATH "${${ARG_NAME}_PREFIX_DEFAULT}")
      if(${ARG_NAME}_PREFIX)
        # if ${ARG_NAME}_PREFIX is set, don't find it anywhere else:
        set(ARG_PREFIX PATHS "${${ARG_NAME}_PREFIX}" NO_DEFAULT_PATH)
      else()
        # allow CMake to search other prefixes if ${ARG_NAME}_PREFIX is not set
        set(ARG_PREFIX)
      endif()
      set(${ARG_NAME}_find_package_args "${${ARG_NAME}_REQUIRED_VERSION}" ${ARG_COMPONENTS}
                                        ${ARG_PREFIX})
      find_package(${ARG_NAME} ${${ARG_NAME}_find_package_args} REQUIRED)
      if(${ARG_NAME}_CONFIG)
        message(STATUS "${ARG_NAME}_CONFIG: ${${ARG_NAME}_CONFIG}")
      endif()
      if(${ARG_NAME}_VERSION)
        message(STATUS "${ARG_NAME}_VERSION: ${${ARG_NAME}_VERSION}")
      endif()
      set(tgt "${CODING_CONV_PREFIX}-${ARG_NAME}")
      add_library(${tgt} INTERFACE)
      if(ARG_TARGETS)
        target_link_libraries(${tgt} INTERFACE ${ARG_TARGETS})
      endif()
      if(ARG_LIBRARY_VARS)
        foreach(library_var IN LISTS ARG_LIBRARY_VARS)
          target_link_libraries(${tgt} INTERFACE ${${library_var}})
        endforeach()
      endif()
      if(ARG_INCLUDE_DIR_VARS)
        foreach(include_dir_var IN LISTS ARG_INCLUDE_DIR_VARS)
          foreach(include_dir IN LISTS ${include_dir_var})
            get_filename_component(abs_include_dir "${include_dir}" ABSOLUTE)
            target_include_directories(${tgt} INTERFACE "${abs_include_dir}")
          endforeach()
        endforeach()
      endif()
      install(
        TARGETS ${tgt}
        EXPORT ${tgt}-target
        RUNTIME DESTINATION bin
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION lib)
      install(EXPORT ${tgt}-target DESTINATION lib/cmake/${CODING_CONV_PREFIX})
      set(${CODING_CONV_PREFIX}_EXPORTED_TARGETS ${${CODING_CONV_PREFIX}_EXPORTED_TARGETS} ${tgt})
      if(ARG_PUBLIC)
        set(${CODING_CONV_PREFIX}_DEPS ${${CODING_CONV_PREFIX}_DEPS} ${ARG_NAME})
      endif()
    endif()
  endif()
endmacro(bob_add_dependency)

function(bob_link_dependency tgt type dep)
  if(${CODING_CONV_PREFIX}_USE_${dep})
    target_link_libraries(${tgt} ${type} ${CODING_CONV_PREFIX}-${dep})
  endif()
endfunction(bob_link_dependency)

macro(bob_private_dep pkg_name)
  bob_add_dependency(PRIVATE NAME "${pkg_name}")
endmacro(bob_private_dep)

macro(bob_public_dep pkg_name)
  bob_add_dependency(PUBLIC NAME "${pkg_name}")
endmacro(bob_public_dep)

function(bob_target_includes lib_name)
  # find local headers even with #include <>
  target_include_directories(${lib_name} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
  # find generated configuration headers
  target_include_directories(${lib_name} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>)
endfunction(bob_target_includes)

function(bob_library_includes lib_name)
  bob_target_includes("${lib_name}")
  # ensure downstream users include installed headers
  target_include_directories(${lib_name} INTERFACE $<INSTALL_INTERFACE:include>)
endfunction(bob_library_includes)

function(bob_export_target tgt_name)
  get_target_property(tgt_type "${tgt_name}" TYPE)
  if(${tgt_type} STREQUAL "EXECUTABLE")
    install(TARGETS ${tgt_name} DESTINATION bin)
  else()
    if(USE_XSDK_DEFAULTS)
      install(TARGETS ${tgt_name} DESTINATION lib)
    else()
      install(
        TARGETS ${tgt_name}
        EXPORT ${tgt_name}-target
        DESTINATION lib)
      install(
        EXPORT ${tgt_name}-target
        NAMESPACE ${CODING_CONV_PREFIX}::
        DESTINATION lib/cmake/${CODING_CONV_PREFIX})
      set(${CODING_CONV_PREFIX}_EXPORTED_TARGETS
          ${${CODING_CONV_PREFIX}_EXPORTED_TARGETS} ${tgt_name}
          PARENT_SCOPE)
    endif()
  endif()
endfunction(bob_export_target)

macro(bob_end_subdir)
  set(${CODING_CONV_PREFIX}_EXPORTED_TARGETS
      ${${CODING_CONV_PREFIX}_EXPORTED_TARGETS}
      PARENT_SCOPE)
  set(${CODING_CONV_PREFIX}_DEPS
      ${${CODING_CONV_PREFIX}_DEPS}
      PARENT_SCOPE)
  set(${CODING_CONV_PREFIX}_DEP_PREFIXES
      ${${CODING_CONV_PREFIX}_DEP_PREFIXES}
      PARENT_SCOPE)
endmacro(bob_end_subdir)

function(bob_config_header HEADER_PATH)
  get_filename_component(HEADER_NAME "${HEADER_PATH}" NAME)
  string(REPLACE "." "_" INCLUDE_GUARD "${HEADER_NAME}")
  string(TOUPPER "${INCLUDE_GUARD}" INCLUDE_GUARD)
  set(HEADER_CONTENT
      "#ifndef ${INCLUDE_GUARD}
#define ${INCLUDE_GUARD}
")
  if(${CODING_CONV_PREFIX}_KEY_BOOLS)
    foreach(KEY_BOOL IN LISTS ${CODING_CONV_PREFIX}_KEY_BOOLS)
      if(${KEY_BOOL})
        string(TOUPPER "${KEY_BOOL}" MACRO_NAME)
        set(HEADER_CONTENT "${HEADER_CONTENT}
#define ${MACRO_NAME}")
      endif()
    endforeach()
  endif()
  if(${CODING_CONV_PREFIX}_KEY_INTS)
    foreach(KEY_INT IN LISTS ${CODING_CONV_PREFIX}_KEY_INTS)
      string(TOUPPER "${KEY_INT}" MACRO_NAME)
      set(HEADER_CONTENT "${HEADER_CONTENT}
#define ${MACRO_NAME} ${${KEY_INT}}")
    endforeach()
  endif()
  if(${CODING_CONV_PREFIX}_KEY_STRINGS)
    foreach(KEY_STRING IN LISTS ${CODING_CONV_PREFIX}_KEY_STRINGS)
      string(TOUPPER "${KEY_STRING}" MACRO_NAME)
      set(val "${${KEY_STRING}}")
      # escape escapes
      string(REPLACE "\\" "\\\\" val "${val}")
      # escape quotes
      string(REPLACE "\"" "\\\"" val "${val}")
      set(HEADER_CONTENT "${HEADER_CONTENT}
#define ${MACRO_NAME} \"${val}\"")
    endforeach()
  endif()
  set(HEADER_CONTENT
      "${HEADER_CONTENT}

#endif
")
  file(WRITE "${HEADER_PATH}" "${HEADER_CONTENT}")
endfunction()

function(bob_get_link_libs tgt var)
  get_target_property(tgt_type "${tgt}" TYPE)
  set(sublibs)
  if(NOT tgt_type STREQUAL "INTERFACE_LIBRARY")
    get_target_property(tgt_libs "${tgt}" LINK_LIBRARIES)
    if(tgt_libs)
      set(sublibs ${sublibs} ${tgt_libs})
    endif()
  endif()
  get_target_property(tgt_iface_libs "${tgt}" INTERFACE_LINK_LIBRARIES)
  if(tgt_iface_libs)
    set(sublibs ${sublibs} ${tgt_iface_libs})
  endif()
  set(link_libs)
  foreach(lib IN LISTS sublibs)
    if(TARGET ${lib})
      get_target_property(subtgt_type "${lib}" TYPE)
      if(subtgt_type MATCHES "STATIC_LIBRARY|SHARED_LIBRARY")
        get_target_property(sublibtgt_loc "${lib}" LOCATION)
        if(sublibtgt_loc)
          set(link_libs ${link_libs} ${sublibtgt_loc})
        endif()
      endif()
      if(subtgt_type MATCHES "UNKNOWN_LIBRARY")
        foreach(prop in ITEMS IMPORTED_LOCATION IMPORTED_LOCATION_RELEASE IMPORTED_LOCATION_DEBUG)
          get_target_property(sublibtgt_import_loc "${lib}" ${prop})
          if(sublibtgt_import_loc)
            set(link_libs ${link_libs} ${sublibtgt_import_loc})
          endif()
        endforeach()
      endif()
      bob_get_link_libs(${lib} subtgt_link_libs)
      set(link_libs ${link_libs} ${subtgt_link_libs})
    else()
      set(link_libs ${link_libs} ${lib})
    endif()
  endforeach()
  if(link_libs)
    list(REVERSE link_libs)
    list(REMOVE_DUPLICATES link_libs)
    list(REVERSE link_libs)
  endif()
  set(${var}
      ${link_libs}
      PARENT_SCOPE)
endfunction()

function(bob_install_provenance)
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}_cmake_args.txt
       "${${CODING_CONV_PREFIX}_CMAKE_ARGS}")
  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}_cmake_args.txt
          DESTINATION lib/cmake/${CODING_CONV_PREFIX})
  get_property(languages GLOBAL PROPERTY ENABLED_LANGUAGES)
  string(STRIP "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE)
  string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type_upper)
  foreach(lang IN LISTS languages)
    file(
      WRITE ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}_${lang}_compile_line.txt
      "${CMAKE_${lang}_COMPILER} ${CMAKE_${lang}_FLAGS} ${CMAKE_${lang}_FLAGS_${build_type_upper}}")
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}_${lang}_compile_line.txt
            DESTINATION lib/cmake/${CODING_CONV_PREFIX})
  endforeach()
  foreach(tgt IN LISTS ${CODING_CONV_PREFIX}_EXPORTED_TARGETS)
    get_target_property(tgt_type "${tgt}" TYPE)
    if(tgt_type MATCHES "STATIC_LIBRARY|SHARED_LIBRARY")
      bob_get_link_libs(${tgt} link_libs)
      file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}_${tgt}_libs.txt "${link_libs}")
      install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}_${tgt}_libs.txt
              DESTINATION lib/cmake/${CODING_CONV_PREFIX})
    endif()
  endforeach()
endfunction(bob_install_provenance)

function(bob_end_package)
  include(CMakePackageConfigHelpers)
  set(INCLUDE_INSTALL_DIR include)
  set(LIB_INSTALL_DIR lib)
  set(LATEST_FIND_DEPENDENCY
      "#The definition of this macro is really inconvenient prior to CMake
#commit ab358d6a859d8b7e257ed1e06ca000e097a32ef6
#we'll just copy the latest code into our Config.cmake file
macro(latest_find_dependency dep)
  if (NOT \${dep}_FOUND)
    set(cmake_fd_quiet_arg)
    if(\${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY)
      set(cmake_fd_quiet_arg QUIET)
    endif()
    set(cmake_fd_required_arg)
    if(\${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
      set(cmake_fd_required_arg REQUIRED)
    endif()

    get_property(cmake_fd_alreadyTransitive GLOBAL PROPERTY
      _CMAKE_\${dep}_TRANSITIVE_DEPENDENCY
    )

    find_package(\${dep} \${ARGN}
      \${cmake_fd_quiet_arg}
      \${cmake_fd_required_arg}
    )

    if(NOT DEFINED cmake_fd_alreadyTransitive OR cmake_fd_alreadyTransitive)
      set_property(GLOBAL PROPERTY _CMAKE_\${dep}_TRANSITIVE_DEPENDENCY TRUE)
    endif()

    if (NOT \${dep}_FOUND)
      set(\${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE \"\${CMAKE_FIND_PACKAGE_NAME} could not be found because dependency \${dep} could not be found.\")
      set(\${CMAKE_FIND_PACKAGE_NAME}_FOUND False)
      return()
    endif()
    set(cmake_fd_required_arg)
    set(cmake_fd_quiet_arg)
    set(cmake_fd_exact_arg)
  endif()
endmacro(latest_find_dependency)")
  set(FIND_DEPS_CONTENT)
  foreach(dep IN LISTS ${CODING_CONV_PREFIX}_DEPS)
    string(REPLACE ";" " " FIND_DEP_ARGS "${${dep}_find_package_args}")
    set(FIND_DEPS_CONTENT "${FIND_DEPS_CONTENT}
latest_find_dependency(${dep} ${FIND_DEP_ARGS})")
  endforeach()
  set(CONFIG_CONTENT
      "set(${CODING_CONV_PREFIX}_VERSION ${${CODING_CONV_PREFIX}_VERSION})
${LATEST_FIND_DEPENDENCY}
${FIND_DEPS_CONTENT}
set(${CODING_CONV_PREFIX}_EXPORTED_TARGETS \"${${CODING_CONV_PREFIX}_EXPORTED_TARGETS}\")
foreach(tgt IN LISTS ${CODING_CONV_PREFIX}_EXPORTED_TARGETS)
  include(\${CMAKE_CURRENT_LIST_DIR}/\${tgt}-target.cmake)
endforeach()")
  foreach(TYPE IN ITEMS "BOOL" "INT" "STRING")
    if(${CODING_CONV_PREFIX}_KEY_${TYPE}S)
      foreach(KEY_${TYPE} IN LISTS ${CODING_CONV_PREFIX}_KEY_${TYPE}S)
        set(val "${${KEY_${TYPE}}}")
        # escape escapes
        string(REPLACE "\\" "\\\\" val "${val}")
        # escape quotes
        string(REPLACE "\"" "\\\"" val "${val}")
        set(CONFIG_CONTENT "${CONFIG_CONTENT}
set(${KEY_${TYPE}} \"${val}\")")
      endforeach()
    endif()
  endforeach()
  set(CONFIG_CONTENT "${CONFIG_CONTENT}
")
  install(FILES "${PROJECT_BINARY_DIR}/${CODING_CONV_PREFIX}Config.cmake"
          DESTINATION lib/cmake/${CODING_CONV_PREFIX})
  if(PROJECT_VERSION)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}Config.cmake "${CONFIG_CONTENT}")
    write_basic_package_version_file(
      ${CMAKE_CURRENT_BINARY_DIR}/${CODING_CONV_PREFIX}ConfigVersion.cmake
      VERSION ${PROJECT_VERSION}
      COMPATIBILITY SameMajorVersion)
    install(FILES "${PROJECT_BINARY_DIR}/${CODING_CONV_PREFIX}ConfigVersion.cmake"
            DESTINATION lib/cmake/${CODING_CONV_PREFIX})
  endif()
  bob_install_provenance()
endfunction(bob_end_package)
