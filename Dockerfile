FROM ubuntu:22.04

# Avoid tzdata interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install FFmpeg, Intel Media Drivers, and Python
RUN apt-get update && apt-get install -y \
    ffmpeg \
    intel-media-va-driver-non-free \
    vainfo \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install requests library
RUN pip3 install requests

# Set working directory and copy our script
WORKDIR /app
COPY timelapse.py .

# Run the script
CMD ["python3", "-u", "timelapse.py"]