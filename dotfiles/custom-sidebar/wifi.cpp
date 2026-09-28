#include "wifi.hpp"
#include <cstdio>
#include <memory>
#include <sstream>
#include <iostream>

static std::string execCmd(const std::string &cmd) {
    char buffer[256];
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) return "";
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        result += buffer;
    }
    return result;
}

bool WifiManager::isPowered() {
    std::string out = execCmd("nmcli radio wifi 2>/dev/null");
    return out.find("enabled") != std::string::npos;
}

void WifiManager::setPowered(bool on) {
    execCmd(on ? "nmcli radio wifi on >/dev/null 2>&1" : "nmcli radio wifi off >/dev/null 2>&1");
}

void WifiManager::rescan() {
    execCmd("nmcli dev wifi rescan >/dev/null 2>&1 &");
}

std::vector<WifiNetwork> WifiManager::getNetworks() {
    std::vector<WifiNetwork> list;
    // Format: IN-USE:SSID:SIGNAL:SECURITY
    std::string out = execCmd("nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null");
    std::istringstream stream(out);
    std::string line;

    while (std::getline(stream, line)) {
        if (line.empty()) continue;
        std::istringstream liness(line);
        std::string inUseStr, ssid, signalStr, security;

        std::getline(liness, inUseStr, ':');
        std::getline(liness, ssid, ':');
        std::getline(liness, signalStr, ':');
        std::getline(liness, security);

        if (ssid.empty()) continue;

        // Deduplicate SSID
        bool exists = false;
        for (auto &n : list) {
            if (n.ssid == ssid) {
                exists = true;
                break;
            }
        }
        if (exists) continue;

        WifiNetwork net;
        net.inUse = (inUseStr == "*");
        net.ssid = ssid;
        try {
            net.signal = std::stoi(signalStr);
        } catch (...) {
            net.signal = 50;
        }
        net.security = security;
        net.secure = (!security.empty() && security.find("--") == std::string::npos);

        if (net.secure) net.icon = "wifi_lock";
        else net.icon = "wifi";

        list.push_back(net);
    }
    return list;
}

bool WifiManager::connect(const std::string &ssid, const std::string &password) {
    std::string cmd;
    if (password.empty()) {
        cmd = "nmcli dev wifi connect \"" + ssid + "\" 2>&1";
    } else {
        cmd = "nmcli dev wifi connect \"" + ssid + "\" password \"" + password + "\" 2>&1";
    }
    std::string out = execCmd(cmd);
    return out.find("successfully activated") != std::string::npos;
}
