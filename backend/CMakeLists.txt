cmake_minimum_required(VERSION 3.16)
project(DesktopAppBackend)

# 设置C++标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置输出目录
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# 优先查找系统包，然后回退到vcpkg
# 查找nlohmann_json - 优先使用系统包
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(NLOHMANN_JSON QUIET nlohmann_json)
endif()

if(NOT NLOHMANN_JSON_FOUND)
    # 回退到find_package方式（支持vcpkg和系统安装）
    find_package(nlohmann_json CONFIG QUIET)
    if(NOT nlohmann_json_FOUND)
        find_package(nlohmann_json REQUIRED)
    endif()
endif()

# 查找httplib - 优先使用项目本地的header文件
set(HTTPLIB_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
if(EXISTS "${HTTPLIB_INCLUDE_DIR}/httplib.h")
    message(STATUS "Found cpp-httplib header in project: ${HTTPLIB_INCLUDE_DIR}/httplib.h")
    set(HTTPLIB_FOUND TRUE)
else()
    # 备用：在系统路径中查找
    find_path(HTTPLIB_INCLUDE_DIR 
        NAMES httplib.h
        PATHS 
            /usr/local/include
            /usr/include
            ${CMAKE_PREFIX_PATH}/include
        DOC "cpp-httplib header file"
    )
    
    if(HTTPLIB_INCLUDE_DIR)
        message(STATUS "Found cpp-httplib header in system: ${HTTPLIB_INCLUDE_DIR}")
        set(HTTPLIB_FOUND TRUE)
    else()
        # 最后回退到vcpkg方式
        find_package(httplib CONFIG QUIET)
        if(httplib_FOUND)
            set(HTTPLIB_FOUND TRUE)
            message(STATUS "Found cpp-httplib via vcpkg")
        else()
            message(FATAL_ERROR "cpp-httplib not found! Please ensure httplib.h is in include/ directory")
        endif()
    endif()
endif()

# 添加可执行文件
add_executable(backend
    src/main.cpp
    src/user_service.cpp
    src/http_server.cpp
)

# 包含头文件目录
target_include_directories(backend PRIVATE include)

# 链接库 - 适配不同的查找方式
if(NLOHMANN_JSON_FOUND AND PkgConfig_FOUND)
    # 使用pkg-config找到的包
    target_link_libraries(backend PRIVATE ${NLOHMANN_JSON_LIBRARIES})
    target_include_directories(backend PRIVATE ${NLOHMANN_JSON_INCLUDE_DIRS})
    target_compile_options(backend PRIVATE ${NLOHMANN_JSON_CFLAGS_OTHER})
elseif(TARGET nlohmann_json::nlohmann_json)
    # 使用find_package找到的现代cmake target
    target_link_libraries(backend PRIVATE nlohmann_json::nlohmann_json)
else()
    # 传统方式
    target_link_libraries(backend PRIVATE nlohmann_json)
endif()

# httplib链接
if(TARGET httplib::httplib)
    target_link_libraries(backend PRIVATE httplib::httplib)
else()
    # header-only，已经通过include目录包含
    message(STATUS "Using header-only cpp-httplib from: ${HTTPLIB_INCLUDE_DIR}")
endif()

# 平台特定设置
if(WIN32)
    target_link_libraries(backend PRIVATE ws2_32)
else()
    # Linux/Unix系统需要链接pthread库（httplib依赖）
    find_package(Threads REQUIRED)
    target_link_libraries(backend PRIVATE Threads::Threads)
endif()

# 编译选项
if(MSVC)
    target_compile_options(backend PRIVATE /W4)
else()
    target_compile_options(backend PRIVATE -Wall -Wextra -Wpedantic)
endif()

# 调试信息
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_definitions(backend PRIVATE DEBUG_MODE=1)
endif() 