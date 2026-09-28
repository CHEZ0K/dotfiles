#include "bluetooth.hpp"
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

bool BluetoothManager::isPowered() {
    std::string out = execCmd("bluetoothctl show 2>/dev/null | grep 'Powered:'");
    return out.find("yes") != std::string::npos;
}

void BluetoothManager::setPowered(bool on) {
    execCmd(on ? "bluetoothctl power on >/dev/null 2>&1" : "bluetoothctl power off >/dev/null 2>&1");
}

std::vector<BluetoothDevice> BluetoothManager::getDevices() {
    std::vector<BluetoothDevice> devices;
    std::string out = execCmd("bluetoothctl devices 2>/dev/null");
    std::istringstream stream(out);
    std::string line;

    while (std::getline(stream, line)) {
        if (line.rfind("Device ", 0) == 0) {
            std::istringstream liness(line);
            std::string prefix, mac, namePart, fullName;
            liness >> prefix >> mac;
            while (liness >> namePart) {
                if (!fullName.empty()) fullName += " ";
                fullName += namePart;
            }
            if (mac.empty()) continue;

            BluetoothDevice dev;
            dev.mac = mac;
            dev.name = fullName.empty() ? mac : fullName;

            // Fetch info for device
            std::string info = execCmd("bluetoothctl info " + mac + " 2>/dev/null");
            dev.connected = (info.find("Connected: yes") != std::string::npos);
            dev.paired = (info.find("Paired: yes") != std::string::npos);

            // Icon detection
            if (info.find("audio-headset") != std::string::npos || info.find("Audio Sink") != std::string::npos ||
                dev.name.find("Bass") != std::string::npos || dev.name.find("Space") != std::string::npos ||
                dev.name.find("Headphones") != std::string::npos || dev.name.find("Buds") != std::string::npos) {
                dev.icon = "headphones";
            } else if (info.find("input-mouse") != std::string::npos || dev.name.find("Mouse") != std::string::npos) {
                dev.icon = "mouse";
            } else if (info.find("input-keyboard") != std::string::npos || dev.name.find("Keyboard") != std::string::npos) {
                dev.icon = "keyboard";
            } else if (info.find("phone") != std::string::npos) {
                dev.icon = "smartphone";
            } else {
                dev.icon = "bluetooth";
            }

            // Battery percentage
            size_t batPos = info.find("Battery Percentage:");
            if (batPos != std::string::npos) {
                size_t start = info.find("(", batPos);
                size_t end = info.find(")", start);
                if (start != std::string::npos && end != std::string::npos) {
                    try {
                        dev.battery = std::stoi(info.substr(start + 1, end - start - 1));
                    } catch (...) {}
                }
            }

            devices.push_back(dev);
        }
    }
    return devices;
}

bool BluetoothManager::connectDevice(const std::string &mac) {
    std::string out = execCmd("bluetoothctl connect " + mac + " 2>&1");
    return out.find("Connection successful") != std::string::npos;
}

bool BluetoothManager::disconnectDevice(const std::string &mac) {
    std::string out = execCmd("bluetoothctl disconnect " + mac + " 2>&1");
    return out.find("Successful disconnected") != std::string::npos;
}

void BluetoothManager::startScan() {
    execCmd("timeout 5s bluetoothctl scan on >/dev/null 2>&1 &");
}
