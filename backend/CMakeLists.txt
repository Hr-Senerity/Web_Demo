cmake_minimum_required(VERSION 3.16)
project(DesktopAppBackend)

# 设置C++标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置输出目录
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# 查找依赖包 - 使用vcpkg安装的包  
find_package(httplib CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

# 添加可执行文件
add_executable(backend
    src/main.cpp
    src/user_service.cpp
    src/http_server.cpp
)

# 包含头文件目录
target_include_directories(backend PRIVATE include)

# 链接库
target_link_libraries(backend PRIVATE 
    httplib::httplib
    nlohmann_json::nlohmann_json
)

# Windows特定设置
if(WIN32)
    target_link_libraries(backend PRIVATE ws2_32)
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