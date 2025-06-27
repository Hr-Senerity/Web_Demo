#include <iostream>
#include <signal.h>
#include "http_server.h"

// 全局服务器实例，用于信号处理
HttpServer* g_server = nullptr;

void signalHandler(int signal) {
    std::cout << "\n收到信号 " << signal << "，正在关闭服务器..." << std::endl;
    if (g_server) {
        g_server->stop();
    }
    exit(0);
}

int main() {
    try {
        std::cout << "=== 桌面应用后端服务 ===" << std::endl;
        std::cout << "启动HTTP服务器..." << std::endl;

        // 创建HTTP服务器
        HttpServer server(8080);
        g_server = &server;

        // 注册信号处理器
        signal(SIGINT, signalHandler);  // Ctrl+C
        signal(SIGTERM, signalHandler); // 终止信号

        std::cout << "服务器启动成功！" << std::endl;
        std::cout << "访问地址: http://localhost:8080" << std::endl;
        std::cout << "API文档: " << std::endl;
        std::cout << "  GET    /api/users     - 获取所有用户" << std::endl;
        std::cout << "  GET    /api/users/:id - 获取单个用户" << std::endl;
        std::cout << "  POST   /api/users     - 创建用户" << std::endl;
        std::cout << "  PUT    /api/users/:id - 更新用户" << std::endl;
        std::cout << "  DELETE /api/users/:id - 删除用户" << std::endl;
        std::cout << "按 Ctrl+C 停止服务器" << std::endl;
        std::cout << "========================" << std::endl;

        // 启动服务器（这会阻塞主线程）
        server.start();

    } catch (const std::exception& e) {
        std::cerr << "服务器启动失败: " << e.what() << std::endl;
        return 1;
    }

    return 0;
} 