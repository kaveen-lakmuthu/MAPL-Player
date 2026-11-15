add_library(mapl_test_backends STATIC
    ../src/AudioLevelMeter.h ../src/AudioLevelMeter.cpp
    ../src/PlaybackOptions.h ../src/PlaybackOptions.cpp
    ../src/MprisService.h ../src/MprisService.cpp
    ../src/MprisAdaptors.h ../src/MprisAdaptors.cpp
    ../src/BackgroundProcess.h
    ../src/BackgroundProcess.cpp
    ../src/PlaybackHistory.h
    ../src/PlaybackHistory.cpp
    ../src/PlayerController.cpp
    ../src/PlayerController.h
    ../src/ModelDownloader.cpp
    ../src/ModelDownloader.h
)
target_include_directories(mapl_test_backends PUBLIC ../src)
target_link_libraries(mapl_test_backends PUBLIC
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Multimedia Qt6::Network Qt6::DBus
)

add_executable(mapl_process_helper cpp/process_helper.cpp)
target_link_libraries(mapl_process_helper PRIVATE Qt6::Core)

foreach(test_name IN ITEMS playercontroller modeldownloader playbackhistory)
    add_executable(tst_${test_name} cpp/tst_${test_name}.cpp)
    target_link_libraries(tst_${test_name} PRIVATE mapl_test_backends Qt6::Test)
    target_compile_definitions(tst_${test_name} PRIVATE MAPL_PROCESS_HELPER="$<TARGET_FILE:mapl_process_helper>")
    add_dependencies(tst_${test_name} mapl_process_helper)
    add_test(NAME ${test_name} COMMAND tst_${test_name})
endforeach()

add_executable(tst_qml qml_setup.cpp)
target_compile_definitions(tst_qml PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
    MAPL_SOURCE_DIR="${PROJECT_SOURCE_DIR}"
    MAPL_APP_VERSION="${MAPL_VERSION_STRING}"
)
target_link_libraries(tst_qml PRIVATE mapl_test_backends Qt6::QuickTest Qt6::Quick Qt6::Widgets)
add_test(NAME qml COMMAND tst_qml)
set_tests_properties(qml PROPERTIES
    TIMEOUT 60
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_QUICK_CONTROLS_STYLE=Basic;QT_FORCE_STDERR_LOGGING=1;QML_XHR_ALLOW_FILE_READ=1"
)

add_executable(tst_subtitlegenerator
    cpp/tst_subtitlegenerator.cpp
    cpp/WhisperStub.cpp
    ../src/SubtitleGenerator.h ../src/SubtitleGenerator.cpp
    ../src/TranscriptionWorker.h ../src/TranscriptionWorker.cpp
)
target_link_libraries(tst_subtitlegenerator PRIVATE mapl_test_backends Qt6::Test)
target_compile_definitions(tst_subtitlegenerator PRIVATE MAPL_PROCESS_HELPER="$<TARGET_FILE:mapl_process_helper>")
add_dependencies(tst_subtitlegenerator mapl_process_helper)
add_test(NAME subtitlegenerator COMMAND tst_subtitlegenerator)
set_tests_properties(playercontroller modeldownloader subtitlegenerator PROPERTIES TIMEOUT 30)

foreach(test_name IN ITEMS playbackoptions mpris audiolevelmeter)
    add_executable(tst_${test_name} cpp/tst_${test_name}.cpp)
    target_link_libraries(tst_${test_name} PRIVATE mapl_test_backends Qt6::Test)
endforeach()
add_test(NAME playbackoptions COMMAND tst_playbackoptions)
add_test(NAME audiolevelmeter COMMAND tst_audiolevelmeter)
find_program(DBUS_RUN_SESSION dbus-run-session)
if(NOT DBUS_RUN_SESSION)
    message(FATAL_ERROR "MPRIS tests require dbus-run-session (install the dbus package)")
endif()
add_test(NAME mpris COMMAND ${DBUS_RUN_SESSION} -- $<TARGET_FILE:tst_mpris>)
set_tests_properties(playbackoptions mpris audiolevelmeter PROPERTIES TIMEOUT 40 ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

if(MAPL_BUILD_APP)
    add_executable(tst_installedapplication cpp/tst_installedapplication.cpp)
    target_link_libraries(tst_installedapplication PRIVATE Qt6::Core Qt6::DBus Qt6::Test)
    target_compile_definitions(tst_installedapplication PRIVATE
        MAPL_APP_BINARY="$<TARGET_FILE:mapl-player>"
        MAPL_APP_VERSION="${MAPL_VERSION_STRING}"
    )
    add_dependencies(tst_installedapplication mapl-player)
    add_test(NAME installedapplication COMMAND ${DBUS_RUN_SESSION} -- $<TARGET_FILE:tst_installedapplication>)
    set_tests_properties(installedapplication PROPERTIES TIMEOUT 40)
endif()
