# ==============================================================================
# Makefile for 32-Point Radix-2 DIF FFT C++ Model
# Author: Mostafa Ihab
# ==============================================================================

CXX      = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O3
TARGET   = fft_model_test.exe
SRCS     = fft_radix2_dif.cpp main.cpp

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SRCS)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) *.o

.PHONY: all run clean
