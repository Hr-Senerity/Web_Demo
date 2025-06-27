#pragma once

#include <httplib.h>
#include <memory>
#include "user_service.h"

class HttpServer {
public:
    HttpServer(int port = 8080);
    ~HttpServer();

    void start();
    void stop();

private:
    httplib::Server server_;
    std::unique_ptr<UserService> userService_;
    int port_;

    // 路由处理器
    void setupRoutes();
    void setupCORS();
    
    // API端点
    void handleGetUsers(const httplib::Request& req, httplib::Response& res);
    void handleGetUser(const httplib::Request& req, httplib::Response& res);
    void handleCreateUser(const httplib::Request& req, httplib::Response& res);
    void handleUpdateUser(const httplib::Request& req, httplib::Response& res);
    void handleDeleteUser(const httplib::Request& req, httplib::Response& res);
    
    // 辅助方法
    void sendJsonResponse(httplib::Response& res, int status, const nlohmann::json& data);
    void sendErrorResponse(httplib::Response& res, int status, const std::string& message);
}; 