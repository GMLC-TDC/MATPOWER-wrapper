
cmake_minimum_required(VERSION 3.4)

project(Transmission)

set(CMAKE_CXX_STANDARD 14)

set(Matlab_ROOT_DIR "" CACHE FILEPATH "MATLAB ROOT PATH")

if (Matlab_ROOT_DIR STREQUAL "")
    message (FATAL_ERROR "You did not provide the path to MCR 9.4. You can use ccmake to adjust the Matlab_ROOT_DIR" ) 
endif ()

find_package(HELICS REQUIRED)
find_package(Matlab)

if (Matlab_FOUND)
    find_library(MATLAB_MCR_LIBRARY
        NAMES mwmclmcrrt
        PATHS ${Matlab_ROOT_DIR}/bin ${Matlab_ROOT_DIR}/runtime
        PATH_SUFFIXES maci64 glnxa64 glnx86
    )
    if (MATLAB_MCR_LIBRARY MATCHES "v94")
    else ()
        message (FATAL_ERROR "You provided a wrong version of MCR. We expect 9.4" )
    endif()
endif()

mark_as_advanced(CLEAR Matlab_ROOT_DIR)

find_library(MATPOWER_LIBRARY
    NAMES MATPOWER
    PATHS ${CMAKE_SOURCE_DIR}/src
)

mark_as_advanced(BOOST_INSTALL_PATH)
mark_as_advanced(CMAKE_BUILD_TYPE)
mark_as_advanced(HELICS_APP)
mark_as_advanced(HELICS_BROKER)
mark_as_advanced(HELICS_DIR)
mark_as_advanced(HELICS_PLAYER)
mark_as_advanced(HELICS_RECORDER)
mark_as_advanced(BOOST_INSTALL_PATH)
mark_as_advanced(MATLAB_MCR_LIBRARY)
mark_as_advanced(MATPOWER_LIBRARY)

if(APPLE)
    link_directories(${Matlab_ROOT_DIR}/bin/maci64)
    link_directories(${Matlab_ROOT_DIR}/sys/os/maci64)
endif()

if(UNIX)
    link_directories(${Matlab_ROOT_DIR}/bin/glnxa64)
    link_directories(${Matlab_ROOT_DIR}/sys/os/glnxa64)
endif()

SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib:${CMAKE_INSTALL_PREFIX}/include")

SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

add_executable( start_MATPOWER 
				src/start_MATPOWER.cpp 
				src/read_model_dim.cpp 
				src/read_model_data.cpp 
				src/read_load_profile.cpp 
				src/matpowerintegrator.cpp 
				src/matpowerGeneratorMetrics.cpp
				src/matpowerLoadMetrics.cpp
				src/jsoncpp.cpp
)

target_include_directories(start_MATPOWER PUBLIC ${Matlab_INCLUDE_DIRS})

target_link_libraries(start_MATPOWER ${MATPOWER_LIBRARY})
target_link_libraries(start_MATPOWER ${MATLAB_MCR_LIBRARY})
target_link_libraries(start_MATPOWER ${ZeroMQ_LIBRARY})
target_link_libraries(start_MATPOWER HELICS::helics-static)

install(TARGETS start_MATPOWER DESTINATION bin)
install(FILES src/libMATPOWER.h DESTINATION include)
install(FILES src/libMATPOWER.so DESTINATION lib)

