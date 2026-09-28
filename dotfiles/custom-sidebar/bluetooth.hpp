#pragma once
#include <string>
#include <vector>

struct BluetoothDevice {
    std::string mac;
    std::string name;
    bool connected = false;
    bool paired = false;
    int battery = -1; // -1 if unknown
    std::string icon = "󰂯";
};

class BluetoothManager {
public:
    static std::vector<BluetoothDevice> getDevices();
    static bool isPowered();
    static void setPowered(bool on);
    static bool connectDevice(const std::string &mac);
    static bool disconnectDevice(const std::string &mac);
    static void startScan();
};
