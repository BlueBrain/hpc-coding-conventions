# Create a build rule that copies a file.
#
# cpp_cc_build_time_copy(INPUT <input_path>
#                        OUTPUT <output_path>)
#
# This creates a custom target that is always built and depends on
# `output_path` and a rule to create `output_path` by copying `input_path`.
# This means that changes to the input file (`input_path`, presumably in the
# source tree) can be propagated to `output_path` (presumably in the build
# tree) automatically and without re-running CMake. The existence of a custom
# command that produces `output_path` makes it trivial for other targets to
# declare that they depend on this file.
function(cpp_cc_build_time_copy)
  cmake_parse_arguments(opt "" "INPUT;OUTPUT" "" ${ARGN})
  if(NOT DEFINED opt_INPUT)
    message(ERROR "build_time_copy missing required keyword argument INPUT.")
  endif()
  if(NOT DEFINED opt_OUTPUT)
    message(ERROR "build_time_copy missing required keyword argument OUTPUT.")
  endif()
  string(SHA256 target_name "${opt_INPUT};${opt_OUTPUT}")
  set(target_name "build-time-copy-${target_name}")
  if(NOT TARGET "${target_name}")
    add_custom_command(
      OUTPUT "${opt_OUTPUT}"
      DEPENDS "${opt_INPUT}"
      COMMAND ${CMAKE_COMMAND} -E copy "${opt_INPUT}" "${opt_OUTPUT}")
    add_custom_target(${target_name} ALL DEPENDS "${opt_OUTPUT}")
  endif()
endfunction()
