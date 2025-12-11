cmake_minimum_required(VERSION 3.10)
project(hermod-bifrost VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Qt5 veya Qt6 dene
find_package(Qt6 QUIET COMPONENTS Core Gui Qml Quick Network)
if(NOT Qt6_FOUND)
    find_package(Qt5 REQUIRED COMPONENTS Core Gui Qml Quick Network)
    set(QT_VERSION_MAJOR 5)
    message(STATUS "Using Qt5")
else()
    set(QT_VERSION_MAJOR 6)
    message(STATUS "Using Qt6")
endif()

# QML dosyasını resource olarak ekle
set(QML_RESOURCES MainWindow.qml)
configure_file(MainWindow.qml ${CMAKE_CURRENT_BINARY_DIR}/MainWindow.qml COPYONLY)

add_executable(bifrost
    main.cpp
    tcp_client.h
    tcp_client.cpp
)

if(QT_VERSION_MAJOR EQUAL 6)
    target_link_libraries(bifrost PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Network
    )
else()
    target_link_libraries(bifrost PRIVATE
        Qt5::Core
        Qt5::Gui
        Qt5::Qml
        Qt5::Quick
        Qt5::Network
    )
endif()

install(TARGETS bifrost
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
