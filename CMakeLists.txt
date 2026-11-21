cmake_minimum_required(VERSION 3.16)

project(MAPLPlayerNative VERSION 2.3.15 LANGUAGES CXX C)
set(MAPL_VERSION_STRING "${PROJECT_VERSION}-alpha")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable automatic compilation of Qt Resource and Meta-Object code
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Locate Qt6 Libraries
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia Network Widgets DBus)

include(CTest)
option(MAPL_BUILD_APP "Build the player and its Whisper dependency" ON)

if(MAPL_BUILD_APP)
    if(Qt6_VERSION VERSION_GREATER_EQUAL 6.5)
        qt_policy(SET QTP0001 NEW)
    endif()
    if(Qt6_VERSION VERSION_GREATER_EQUAL 6.8)
        qt_policy(SET QTP0004 NEW)
    endif()

    # Configure FetchContent to download and build whisper.cpp
    include(FetchContent)
    FetchContent_Declare(
        whisper
        GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
        GIT_TAG        v1.8.6
    )

    # Build whisper.cpp as a static library dependency
    # The user-local installer deploys one executable. Never leave it linked
    # to Whisper/ggml shared libraries in the build directory, including when
    # reconfiguring an older cache that enabled shared libraries.
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build bundled dependencies statically" FORCE)
    set(GGML_BACKEND_DL OFF CACHE BOOL "Disable dynamically loaded ggml backends" FORCE)
    set(WHISPER_BUILD_TESTS OFF CACHE BOOL "Disable tests" FORCE)
    set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "Disable examples" FORCE)
    FetchContent_MakeAvailable(whisper)

    # Project sources
    set(SOURCES
        src/AudioLevelMeter.h
        src/AudioLevelMeter.cpp
        src/PlaybackOptions.h
        src/PlaybackOptions.cpp
        src/MprisService.h
        src/MprisService.cpp
        src/MprisAdaptors.h
        src/MprisAdaptors.cpp
        src/main.cpp
        src/PlaybackHistory.h
        src/PlaybackHistory.cpp
        src/PlayerController.h
        src/PlayerController.cpp
        src/SubtitleGenerator.h
        src/SubtitleGenerator.cpp
        src/TranscriptionWorker.h
        src/TranscriptionWorker.cpp
        src/WhisperTranscriber.cpp
        src/BackgroundProcess.h
        src/BackgroundProcess.cpp
        src/ModelDownloader.h
        src/ModelDownloader.cpp
    )

    # Define the native application executable
    qt_add_executable(mapl-player ${SOURCES})
    target_compile_definitions(mapl-player PRIVATE MAPL_APP_VERSION="${MAPL_VERSION_STRING}")
    target_include_directories(mapl-player PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")

    # Link libraries
    target_link_libraries(mapl-player PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Multimedia
        Qt6::Widgets
        Qt6::DBus
        whisper
    )

    # Preserve the resource layout used by relative QML and JavaScript imports.
    set(QML_SOURCES
        qml/components/AudioVisualizer.qml
        qml/components/BackgroundTaskIndicator.qml
        qml/components/DesktopButton.qml
        qml/components/DesktopComboBox.qml
        qml/components/DesktopMenu.qml
        qml/components/DesktopMenuItem.qml
        qml/components/DesktopMenuSeparator.qml
        qml/components/DesktopToolbar.qml
        qml/components/PlayerIcon.qml
        qml/components/FileDrawer.qml
        qml/components/NavigationSidebar.qml
        qml/components/PlaybackControls.qml
        qml/components/PlayerContent.qml
        qml/components/PlayerLayout.qml
        qml/components/SubtitleGeneratorPanel.qml
        qml/components/Timeline.qml
        qml/components/TransportButtons.qml
        qml/components/TransportControls.qml
        qml/components/VolumeControl.qml
        qml/components/VolumeWheelHandler.qml
        qml/dialogs/SubtitleSettingsPopup.qml
        qml/dialogs/BackgroundTasksPopup.qml
        qml/dialogs/SubtitleGenerationPopup.qml
        qml/dialogs/PlaybackOptionsPopup.qml
        qml/dialogs/PlayerPopup.qml
        qml/dialogs/PlayerDialog.qml
        qml/dialogs/ModelManager.qml
        qml/dialogs/RecentFilesMenu.qml
        qml/dialogs/ResumeDialog.qml
        qml/dialogs/AboutDialog.qml
        qml/dialogs/ChaptersPopup.qml
        qml/dialogs/MediaDialogs.qml
        qml/dialogs/SubtitlePicker.qml
        qml/logic/MediaUtils.js
        qml/logic/BackgroundTasks.qml
        qml/logic/DesktopLayout.qml
        qml/logic/PlaybackMemory.qml
        qml/logic/PlaybackSession.qml
        qml/logic/SubtitleJobs.qml
        qml/logic/SubtitleFiles.qml
        qml/logic/SubtitleUtils.js
        qml/main.qml
        qml/views/AudioView.qml
        qml/views/PlaylistView.qml
        qml/views/TranscriptView.qml
        qml/views/VideoView.qml
    )
    foreach(qml_file IN LISTS QML_SOURCES)
        string(REGEX REPLACE "^qml/" "" resource_path "${qml_file}")
        set_source_files_properties(${qml_file} PROPERTIES QT_RESOURCE_ALIAS "${resource_path}")
    endforeach()
    qt_add_qml_module(mapl-player
        URI MAPLPlayerNative
        # The QML import API version is independent of the application release.
        VERSION 1.0
        RESOURCE_PREFIX "/"
        QML_FILES ${QML_SOURCES}
    )

    # Deploy build rules
    install(TARGETS mapl-player
        BUNDLE DESTINATION .
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
    )
endif()

if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test QuickTest)
    add_subdirectory(tests)
endif()
