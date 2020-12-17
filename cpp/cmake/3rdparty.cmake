find_package(Git QUIET)

if(NOT ${CODING_CONV_PREFIX}_THIRD_PARTY_DIR)
  set(${CODING_CONV_PREFIX}_THIRD_PARTY_DIR 3rdparty)
  set(${CODING_CONV_PREFIX}_THIRD_PARTY_DIR
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

# check for external project and initialize submodule if it is missing
function(bbp_add_git_submodule_subdirectory name)
  set(submodule_path "${${CODING_CONV_PREFIX}_THIRD_PARTY_DIR}/${name}")
  if(NOT EXISTS ${CMAKE_SOURCE_DIR}/${submodule_path}/CMakeLists.txt)
    bbp_init_git_submodule("${submodule_path}")
  endif()
  message(STATUS "3rdparty project: using ${name} from \"${submodule_path}\"")
  list(REMOVE_AT ARGV 0)
  add_subdirectory(${submodule_path} ${ARGV})
endfunction()
