FROM ubuntu:22.04

# Avoid tzdata interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install FFmpeg, Intel Media Drivers, Python, and tzdata for timezone support
RUN apt-get update && apt-get install -y \
    ffmpeg \
    intel-media-va-driver-non-free \
    vainfo \
    python3 \
    python3-pip \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install requests

WORKDIR /app
COPY timelapse.py .

CMD ["python3", "-u", "timelapse.py"]