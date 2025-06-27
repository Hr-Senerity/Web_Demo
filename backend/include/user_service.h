#pragma once

#include <string>
#include <vector>
#include <memory>
#include <nlohmann/json.hpp>

struct User {
    int id;
    std::string name;
    std::string email;
    std::string createdAt;
    std::string updatedAt;
    
    // JSON序列化
    nlohmann::json toJson() const;
    static User fromJson(const nlohmann::json& j);
};

class UserService {
public:
    UserService();
    ~UserService();

    // 用户操作
    std::vector<User> getAllUsers() const;
    User getUserById(int id) const;
    User createUser(const std::string& name, const std::string& email);
    User updateUser(int id, const std::string& name, const std::string& email);
    bool deleteUser(int id);

    // 辅助方法
    bool userExists(int id) const;
    bool emailExists(const std::string& email) const;

private:
    std::vector<User> users_;
    int nextId_;
    
    std::string getCurrentDateTime() const;
}; 