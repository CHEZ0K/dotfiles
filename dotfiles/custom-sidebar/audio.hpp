#pragma once
#include <string>
#include <vector>

struct AudioSink {
    int id = 0;
    std::string name;
    bool isDefault = false;
};

class AudioManager {
public:
    static int getVolume();
    static void setVolume(int percent);
    static bool isMuted();
    static void toggleMute();

    static int getBrightness();
    static void setBrightness(int percent);

    static std::vector<AudioSink> getSinks();
    static void setDefaultSink(int id);
};
