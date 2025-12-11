cmake_minimum_required(VERSION 3.10)
project(hermod-polaris)

set(CMAKE_CXX_STANDARD 17)

add_executable(polaris multi_client_server.cpp)

# Threading
find_package(Threads REQUIRED)
target_link_libraries(polaris Threads::Threads)

# Install
install(TARGETS polaris DESTINATION bin)
