cmake_minimum_required(VERSION 3.16)

project(MAPLPlayerNative VERSION 1.0.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable automatic compilation of Qt Resource and Meta-Object code
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Locate Qt6 Libraries
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia Widgets)

# Configure FetchContent to download and build whisper.cpp
include(FetchContent)
FetchContent_Declare(
    whisper
    GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
    GIT_TAG        v1.8.6
)

# Build whisper.cpp as a static library dependency
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "Disable tests" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "Disable examples" FORCE)
FetchContent_MakeAvailable(whisper)

# Project sources
set(SOURCES
    main.cpp
    PlayerController.h
    PlayerController.cpp
    SubtitleGenerator.h
    SubtitleGenerator.cpp
    ModelDownloader.h
    ModelDownloader.cpp
)

# Define the native application executable
qt_add_executable(mapl-player ${SOURCES})

# Link libraries
target_link_libraries(mapl-player PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Multimedia
    Qt6::Widgets
    whisper
)

# Define QML module
qt_add_qml_module(mapl-player
    URI MAPLPlayerNative
    VERSION 1.0
    QML_FILES
        main.qml
)

# Deploy build rules
install(TARGETS mapl-player
    BUNDLE DESTINATION .
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
