#include "user_service.h"
#include <algorithm>
#include <stdexcept>
#include <iomanip>
#include <sstream>
#include <chrono>

// User 结构体方法实现
nlohmann::json User::toJson() const {
    return nlohmann::json{
        {"id", id},
        {"name", name},
        {"email", email},
        {"createdAt", createdAt},
        {"updatedAt", updatedAt}
    };
}

User User::fromJson(const nlohmann::json& j) {
    User user;
    user.id = j.at("id").get<int>();
    user.name = j.at("name").get<std::string>();
    user.email = j.at("email").get<std::string>();
    user.createdAt = j.value("createdAt", "");
    user.updatedAt = j.value("updatedAt", "");
    return user;
}

// UserService 实现
UserService::UserService() : nextId_(1) {
    // 添加一些示例数据
    createUser("张三", "zhang@example.com");
    createUser("李四", "li@example.com");
    createUser("王五", "wang@example.com");
}

UserService::~UserService() = default;

std::vector<User> UserService::getAllUsers() const {
    return users_;
}

User UserService::getUserById(int id) const {
    auto it = std::find_if(users_.begin(), users_.end(),
        [id](const User& user) { return user.id == id; });
    
    if (it == users_.end()) {
        throw std::runtime_error("用户不存在");
    }
    
    return *it;
}

User UserService::createUser(const std::string& name, const std::string& email) {
    if (name.empty() || email.empty()) {
        throw std::runtime_error("姓名和邮箱不能为空");
    }
    
    if (emailExists(email)) {
        throw std::runtime_error("邮箱已存在");
    }
    
    User user;
    user.id = nextId_++;
    user.name = name;
    user.email = email;
    user.createdAt = getCurrentDateTime();
    user.updatedAt = user.createdAt;
    
    users_.push_back(user);
    return user;
}

User UserService::updateUser(int id, const std::string& name, const std::string& email) {
    auto it = std::find_if(users_.begin(), users_.end(),
        [id](const User& user) { return user.id == id; });
    
    if (it == users_.end()) {
        throw std::runtime_error("用户不存在");
    }
    
    if (!name.empty()) {
        it->name = name;
    }
    
    if (!email.empty()) {
        if (email != it->email && emailExists(email)) {
            throw std::runtime_error("邮箱已存在");
        }
        it->email = email;
    }
    
    it->updatedAt = getCurrentDateTime();
    return *it;
}

bool UserService::deleteUser(int id) {
    auto it = std::find_if(users_.begin(), users_.end(),
        [id](const User& user) { return user.id == id; });
    
    if (it == users_.end()) {
        return false;
    }
    
    users_.erase(it);
    return true;
}

bool UserService::userExists(int id) const {
    return std::find_if(users_.begin(), users_.end(),
        [id](const User& user) { return user.id == id; }) != users_.end();
}

bool UserService::emailExists(const std::string& email) const {
    return std::find_if(users_.begin(), users_.end(),
        [&email](const User& user) { return user.email == email; }) != users_.end();
}

std::string UserService::getCurrentDateTime() const {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    return ss.str();
} 