#include "http_server.h"
#include <iostream>
#include <regex>

HttpServer::HttpServer(int port) : port_(port) {
    userService_ = std::make_unique<UserService>();
    setupCORS();
    setupRoutes();
}

HttpServer::~HttpServer() = default;

void HttpServer::start() {
    std::cout << "HTTP服务器监听端口: " << port_ << std::endl;
    server_.listen("0.0.0.0", port_);
}

void HttpServer::stop() {
    server_.stop();
}

void HttpServer::setupCORS() {
    // 设置CORS预检请求
    server_.set_pre_routing_handler([](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        res.set_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization");
        return httplib::Server::HandlerResponse::Unhandled;
    });

    // 处理OPTIONS请求
    server_.Options(".*", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        res.set_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization");
        res.status = 200;
    });
}

void HttpServer::setupRoutes() {
    // 获取所有用户
    server_.Get("/api/users", [this](const httplib::Request& req, httplib::Response& res) {
        handleGetUsers(req, res);
    });

    // 获取单个用户
    server_.Get(R"(/api/users/(\d+))", [this](const httplib::Request& req, httplib::Response& res) {
        handleGetUser(req, res);
    });

    // 创建用户
    server_.Post("/api/users", [this](const httplib::Request& req, httplib::Response& res) {
        handleCreateUser(req, res);
    });

    // 更新用户
    server_.Put(R"(/api/users/(\d+))", [this](const httplib::Request& req, httplib::Response& res) {
        handleUpdateUser(req, res);
    });

    // 删除用户
    server_.Delete(R"(/api/users/(\d+))", [this](const httplib::Request& req, httplib::Response& res) {
        handleDeleteUser(req, res);
    });

    // 健康检查
    server_.Get("/health", [](const httplib::Request&, httplib::Response& res) {
        nlohmann::json response = {
            {"status", "ok"},
            {"message", "服务运行正常"}
        };
        res.set_content(response.dump(), "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");
    });
}

void HttpServer::handleGetUsers(const httplib::Request&, httplib::Response& res) {
    try {
        auto users = userService_->getAllUsers();
        nlohmann::json jsonUsers = nlohmann::json::array();
        
        for (const auto& user : users) {
            jsonUsers.push_back(user.toJson());
        }
        
        nlohmann::json response = {
            {"success", true},
            {"data", jsonUsers}
        };
        
        sendJsonResponse(res, 200, response);
    } catch (const std::exception& e) {
        sendErrorResponse(res, 500, e.what());
    }
}

void HttpServer::handleGetUser(const httplib::Request& req, httplib::Response& res) {
    try {
        int id = std::stoi(req.matches[1]);
        auto user = userService_->getUserById(id);
        
        nlohmann::json response = {
            {"success", true},
            {"data", user.toJson()}
        };
        
        sendJsonResponse(res, 200, response);
    } catch (const std::exception& e) {
        sendErrorResponse(res, 404, e.what());
    }
}

void HttpServer::handleCreateUser(const httplib::Request& req, httplib::Response& res) {
    try {
        auto json = nlohmann::json::parse(req.body);
        
        std::string name = json.at("name").get<std::string>();
        std::string email = json.at("email").get<std::string>();
        
        auto user = userService_->createUser(name, email);
        
        nlohmann::json response = {
            {"success", true},
            {"data", user.toJson()},
            {"message", "用户创建成功"}
        };
        
        sendJsonResponse(res, 201, response);
    } catch (const nlohmann::json::exception& e) {
        sendErrorResponse(res, 400, "无效的JSON格式");
    } catch (const std::exception& e) {
        sendErrorResponse(res, 400, e.what());
    }
}

void HttpServer::handleUpdateUser(const httplib::Request& req, httplib::Response& res) {
    try {
        int id = std::stoi(req.matches[1]);
        auto json = nlohmann::json::parse(req.body);
        
        std::string name = json.value("name", "");
        std::string email = json.value("email", "");
        
        auto user = userService_->updateUser(id, name, email);
        
        nlohmann::json response = {
            {"success", true},
            {"data", user.toJson()},
            {"message", "用户更新成功"}
        };
        
        sendJsonResponse(res, 200, response);
    } catch (const nlohmann::json::exception& e) {
        sendErrorResponse(res, 400, "无效的JSON格式");
    } catch (const std::exception& e) {
        sendErrorResponse(res, 400, e.what());
    }
}

void HttpServer::handleDeleteUser(const httplib::Request& req, httplib::Response& res) {
    try {
        int id = std::stoi(req.matches[1]);
        
        bool success = userService_->deleteUser(id);
        if (!success) {
            sendErrorResponse(res, 404, "用户不存在");
            return;
        }
        
        nlohmann::json response = {
            {"success", true},
            {"message", "用户删除成功"}
        };
        
        sendJsonResponse(res, 200, response);
    } catch (const std::exception& e) {
        sendErrorResponse(res, 400, e.what());
    }
}

void HttpServer::sendJsonResponse(httplib::Response& res, int status, const nlohmann::json& data) {
    res.status = status;
    res.set_content(data.dump(), "application/json");
    res.set_header("Access-Control-Allow-Origin", "*");
}

void HttpServer::sendErrorResponse(httplib::Response& res, int status, const std::string& message) {
    nlohmann::json error = {
        {"success", false},
        {"error", message}
    };
    
    sendJsonResponse(res, status, error);
} 