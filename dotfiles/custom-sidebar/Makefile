CXX = g++
CXXFLAGS = -O2 -Wall -std=c++20 $(shell pkg-config --cflags gtk4 gtk4-layer-shell-0)
LDFLAGS = $(shell pkg-config --libs gtk4 gtk4-layer-shell-0) -lpthread

TARGET = /home/chezok/.local/bin/custom-sidebar
SRCS = main.cpp sidebar.cpp bluetooth.cpp wifi.cpp audio.cpp timer.cpp
OBJS = $(SRCS:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	mkdir -p /home/chezok/.local/bin
	$(CXX) $(OBJS) -o $(TARGET) $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
