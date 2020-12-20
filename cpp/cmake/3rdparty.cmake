find_package(Git QUIET)

if(NOT ${CODING_CONV_PREFIX}_3RDPARTY_DIR)
  set(${CODING_CONV_PREFIX}_3RDPARTY_DIR 3rdparty)
  set(${CODING_CONV_PREFIX}_3RDPARTY_DIR
      3rdparty
      PARENT_SCOPE)
endif()

# initialize submodule with given path
function(bbp_init_git_submodule path)
  if(NOT ${GIT_FOUND})
    message(
      FATAL_ERROR "git not found and ${path} submodule not cloned (use git clone --recursive)")
  endif()
  message(
    STATUS "Fetching git submodule ${path}: running git submodule update --init --recursive ${path}"
  )
  execute_process(
    COMMAND
      ${GIT_EXECUTABLE} submodule update --init --recursive -- ${path}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    RESULT_VARIABLE git_submodule_status)
  if(NOT git_submodule_status EQUAL 0)
    message(FATAL_ERROR "Could not clone git submodule ${path}")
  endif()
endfunction()

# use a git submodule
#
# bbp_git_submodule(source_dir
#                   [DISABLED]
#                   [BUILD] [<arguments>]
#
# Add a CMake option in the cache to control whether the
# submodule is used or not (default ON). The option is named after the source
# directory passed in first argument, for instance:
#   bbp_git_submodule(src/eigen)
# adds the following CMake cached option:
#  ${PROJECT_NAME}_3RDPARTY_USE_SRC_EIGEN:BOOL=ON
#
# If enabled, then the submodule is fetched if missing in the working copy.
#
# If the DISABLED argument is provided, then the default value for the CMake
# option is OFF.
#
# if the BUILD argument is provided then the directory is added to the build
# through the add_subdirectory CMake function. Arguments following the BUILD
# arguments are passed to the add_subdirectory function call.
#
function(bbp_git_submodule name)
  cmake_parse_arguments(PARSE_ARGV 1 opt "DISABLED" "" "BUILD")
  string(MAKE_C_IDENTIFIER "USE_${name}" option_suffix)
  string(TOUPPER "3RDPARTY_${option_suffix}" option_suffix)
  if(opt_DISABLED)
    set(default OFF)
  else()
    set(default ON)
  endif()
  option(${CODING_CONV_PREFIX}_${option_suffix}
          "Use the git submodule ${name}"
          ${default})
  if(NOT ${CODING_CONV_PREFIX}_${option_suffix})
    message(STATUS RETURN)
    return()
  endif()
  set(submodule_path "${${CODING_CONV_PREFIX}_3RDPARTY_DIR}/${name}")
  if(NOT EXISTS ${CMAKE_SOURCE_DIR}/${submodule_path}/CMakeLists.txt)
    bbp_init_git_submodule("${submodule_path}")
  endif()
  message(STATUS "3rdparty project: using ${name} from \"${submodule_path}\"")
  if(opt_BUILD)
      add_subdirectory(${submodule_path} ${opt_BUILD})
  elseif("BUILD" IN_LIST opt_KEYWORDS_MISSING_VALUES)
    add_subdirectory(${submodule_path})
  endif()
endfunction()
