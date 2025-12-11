# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Debug")
  file(REMOVE_RECURSE
  "CMakeFiles\\bifrost_autogen.dir\\AutogenUsed.txt"
  "CMakeFiles\\bifrost_autogen.dir\\ParseCache.txt"
  "bifrost_autogen"
  )
endif()
