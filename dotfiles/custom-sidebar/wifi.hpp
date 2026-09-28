#pragma once
#include <string>
#include <vector>

struct WifiNetwork {
    std::string ssid;
    int signal = 0;
    bool inUse = false;
    bool secure = false;
    std::string security;
    std::string icon = "󰤨";
};

class WifiManager {
public:
    static std::vector<WifiNetwork> getNetworks();
    static bool isPowered();
    static void setPowered(bool on);
    static bool connect(const std::string &ssid, const std::string &password);
    static void rescan();
};
