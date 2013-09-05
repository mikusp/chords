cmake_minimum_required(VERSION 2.6)

project(Chords)

list(APPEND CMAKE_MODULE_PATH
    ${CMAKE_SOURCE_DIR}/cmake/vala
)

include(FindVala)
include(UseVala)

find_package(Vala)

find_package(PkgConfig)
pkg_check_modules(LIBS REQUIRED
    gtk+-3.0
    gstreamer-1.0
    gstreamer-app-1.0
    gstreamer-base-1.0
    gee-0.8)
add_definitions(${LIBS_CFLAGS} ${LIBS_CFLAGS_OTHER})
link_libraries(${LIBS_LIBRARIES})
link_directories(${LIBS_LIBRARY_DIRS})
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lm")


vala_precompile(VALA_C
    src/AudioManager.vala
    src/Chords.vala
    src/FileSource.vala
    src/WaveformWidget.vala
    src/Renderable.vala
    src/UnitsConverter.vala
    src/Waveform.vala
    src/HelperFunctions.vala
    src/Marker.vala
    src/BeatMarker.vala
    src/MeasureMarker.vala
    src/SectionMarker.vala
PACKAGES
    gtk+-3.0
    gstreamer-1.0
    gee-0.8
CUSTOM_VAPIS
    vapi/gstreamer-app-1.0.vapi  # those are modified
    vapi/gstreamer-base-1.0.vapi
OPTIONS
    -g
)

add_executable(Chords ${VALA_C})

add_custom_command(TARGET Chords PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${CMAKE_SOURCE_DIR}/ui $<TARGET_FILE_DIR:Chords>)

