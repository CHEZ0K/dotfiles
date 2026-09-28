#include "audio.hpp"
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

int AudioManager::getVolume() {
    std::string out = execCmd("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null");
    // Format: Volume: 0.50 [MUTED]
    size_t pos = out.find("Volume: ");
    if (pos != std::string::npos) {
        try {
            float vol = std::stof(out.substr(pos + 8));
            return (int)(vol * 100.0f + 0.5f);
        } catch (...) {}
    }
    return 50;
}

void AudioManager::setVolume(int percent) {
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    float vol = percent / 100.0f;
    execCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + std::to_string(vol) + " >/dev/null 2>&1");
}

bool AudioManager::isMuted() {
    std::string out = execCmd("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null");
    return out.find("[MUTED]") != std::string::npos;
}

void AudioManager::toggleMute() {
    execCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1");
}

int AudioManager::getBrightness() {
    std::string out = execCmd("brightnessctl g 2>/dev/null");
    std::string maxOut = execCmd("brightnessctl m 2>/dev/null");
    try {
        int cur = std::stoi(out);
        int max = std::stoi(maxOut);
        if (max > 0) return (cur * 100) / max;
    } catch (...) {}
    return 100;
}

void AudioManager::setBrightness(int percent) {
    if (percent < 5) percent = 5;
    if (percent > 100) percent = 100;
    execCmd("brightnessctl s " + std::to_string(percent) + "% >/dev/null 2>&1");
}

std::vector<AudioSink> AudioManager::getSinks() {
    std::vector<AudioSink> sinks;
    std::string out = execCmd("wpctl status 2>/dev/null");
    std::istringstream stream(out);
    std::string line;
    bool inSinks = false;

    while (std::getline(stream, line)) {
        if (line.find("Sinks:") != std::string::npos) {
            inSinks = true;
            continue;
        }
        if (inSinks) {
            if (line.find("Sources:") != std::string::npos || line.find("Filters:") != std::string::npos) {
                break;
            }
            // Lines format: " │  *  107. Baseus Bass BP1 Pro                 [vol: 0.26]"
            size_t dotPos = line.find(". ");
            if (dotPos != std::string::npos && dotPos > 4) {
                bool isDef = (line.find('*') != std::string::npos && line.find('*') < dotPos);
                // Extract ID
                size_t numStart = line.rfind(' ', dotPos - 1);
                if (numStart != std::string::npos) {
                    try {
                        int id = std::stoi(line.substr(numStart + 1, dotPos - numStart - 1));
                        size_t nameEnd = line.find('[', dotPos + 2);
                        std::string name = line.substr(dotPos + 2, (nameEnd != std::string::npos) ? (nameEnd - dotPos - 2) : std::string::npos);
                        // trim name
                        size_t lastNonSpace = name.find_last_not_of(" \t\r\n");
                        if (lastNonSpace != std::string::npos) name = name.substr(0, lastNonSpace + 1);

                        AudioSink sink;
                        sink.id = id;
                        sink.name = name;
                        sink.isDefault = isDef;
                        sinks.push_back(sink);
                    } catch (...) {}
                }
            }
        }
    }
    return sinks;
}

void AudioManager::setDefaultSink(int id) {
    execCmd("wpctl set-default " + std::to_string(id) + " >/dev/null 2>&1");
}
