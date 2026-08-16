cmake_minimum_required(VERSION 3.16)

project(ViewerHostQt LANGUAGES CXX)

include(CTest)

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Network Widgets)

add_library(ViewerHostQt STATIC
    src/ViewerHost.cpp
    include/ViewerHost.h
)
add_library(ViewerHostQt::ViewerHostQt ALIAS ViewerHostQt)

target_compile_features(ViewerHostQt PUBLIC cxx_std_17)
target_compile_options(ViewerHostQt PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/utf-8>)
target_include_directories(ViewerHostQt PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(ViewerHostQt PUBLIC Qt5::Core Qt5::Network Qt5::Widgets)
set_target_properties(ViewerHostQt PROPERTIES AUTOMOC ON)

install(TARGETS ViewerHostQt EXPORT ViewerHostQtTargets)
install(FILES include/ViewerHost.h DESTINATION include)
install(EXPORT ViewerHostQtTargets
    FILE ViewerHostQtTargets.cmake
    NAMESPACE ViewerHostQt::
    DESTINATION lib/cmake/ViewerHostQt
)

if(BUILD_TESTING)
    add_executable(ViewerHostQtSmokeTest tests/ViewerHostSmokeTest.cpp)
    target_compile_features(ViewerHostQtSmokeTest PRIVATE cxx_std_17)
    target_compile_options(ViewerHostQtSmokeTest PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/utf-8>)
    target_compile_definitions(ViewerHostQtSmokeTest PRIVATE
        VIEWER_WEB_DIST="${CMAKE_CURRENT_SOURCE_DIR}/../viewer-web/dist"
    )
    target_link_libraries(ViewerHostQtSmokeTest PRIVATE ViewerHostQt::ViewerHostQt)
    add_test(NAME ViewerHostQtSmokeTest COMMAND ViewerHostQtSmokeTest)
    get_target_property(_viewer_host_qmake Qt5::qmake IMPORTED_LOCATION)
    get_filename_component(_viewer_host_qt_bin "${_viewer_host_qmake}" DIRECTORY)
    set_tests_properties(ViewerHostQtSmokeTest PROPERTIES
        ENVIRONMENT "PATH=${_viewer_host_qt_bin}\\;$ENV{PATH}"
    )

    find_package(Qt5 5.15 COMPONENTS WebEngineWidgets QUIET)
    if(Qt5WebEngineWidgets_FOUND)
        add_executable(ViewerHostQtWebEngineTest tests/ViewerHostWebEngineTest.cpp)
        target_compile_features(ViewerHostQtWebEngineTest PRIVATE cxx_std_17)
        target_compile_options(ViewerHostQtWebEngineTest PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/utf-8>)
        target_compile_definitions(ViewerHostQtWebEngineTest PRIVATE
            VIEWER_WEB_DIST="${CMAKE_CURRENT_SOURCE_DIR}/../viewer-web/dist"
        )
        target_link_libraries(ViewerHostQtWebEngineTest PRIVATE
            ViewerHostQt::ViewerHostQt Qt5::WebEngineWidgets)
    endif()
endif()
