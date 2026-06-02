# Hardware-Accelerated Docker Timelapse Recorder

[cite_start]This project runs a highly optimized, single Docker container that automatically fetches a JPEG image from a specified URL every second and compiles 3600 of those frames (1 hour) into an H.265 MKV video timelapse[cite: 1, 2]. 

[cite_start]Instead of writing thousands of images to your drive, this container holds the images in RAM using FFmpeg's `image2pipe` and utilizes Intel Quick Sync Video (QSV) hardware acceleration to offload the video encoding to your integrated GPU[cite: 7, 19, 20].

## Requirements
* [cite_start]**Host OS**: Alpine Linux [cite: 24] [cite_start](The automated installer is built specifically for Alpine's OpenRC init system [cite: 53]).
* [cite_start]**Hardware**: An Intel CPU with integrated graphics (e.g., 12th gen Intel Core processor)[cite: 4].

## Quick Installation

[cite_start]You can install the dependencies, configure Docker, pull the prebuilt container from Docker Hub [cite: 121, 126][cite_start], and set up the background service by running a single command as root[cite: 68, 69]:

```bash
wget -qO- [https://raw.githubusercontent.com/gpocali/docker-hw-timelapse-recorder/main/setup.sh](https://raw.githubusercontent.com/gpocali/docker-hw-timelapse-recorder/main/setup.sh) | sh -s -- --install

```

### What this script does:

1. Installs the `linux-firmware-i915` package and loads the Intel kernel module to expose the iGPU (`/dev/dri`).


2. Installs and enables Docker and Docker Compose.


3. Downloads the `docker-compose.yml` to `/opt/timelapse/`.


4. Installs an OpenRC init script so the service starts cleanly on boot.


5. Adds helpful management commands to your terminal's login screen (MOTD).



## Configuration

After installation, the service will start automatically using default placeholder values. You will need to edit the configuration to point to your actual camera or image source.

1. Open the compose file:
```bash
nano /opt/timelapse/docker-compose.yml

```


2. Update the environment variables:
* `IMAGE_URL`: The URL where the source JPEG is hosted.
* 
`FILE_PREFIX`: A static prefix for your output files (e.g., `cam1_timelapse`).


* `OUTPUT_FPS`: The framerate for the final video (Default is 30).


3. Map your volume: Update the `- /path/to/your/local/output/folder:/output` line to save your MKV files to a permanent directory on your host. Files are saved in a `YYYY/MM/DD/HH` folder structure.


4. Restart the service to apply changes:
```bash
rc-service timelapse restart

```



## Service Management

Because this project is registered as a native Alpine service , you can manage it using standard `rc-service` commands:

* **Start the service**: `rc-service timelapse start`
* **Stop the service**: `rc-service timelapse stop`
* **Restart the service**: `rc-service timelapse restart`
* **Check status**: `rc-service timelapse status`

### Troubleshooting and Logs

If you need to diagnose issues, the init script provides custom interactive commands:

* **View Real-Time Logs**: `rc-service timelapse logs`


*(Streams standard output. Press `Ctrl+C` to exit)*.


* **Open a Shell**: `rc-service timelapse shell`


*(Drops you into a root bash prompt inside the running container to check mounts or test the script. Type `exit` to return)*.



## Uninstallation

To safely stop the container, remove the init scripts, and clean up your login screen, run the uninstallation command:

```bash
wget -qO- [https://raw.githubusercontent.com/gpocali/docker-hw-timelapse-recorder/main/setup.sh](https://raw.githubusercontent.com/gpocali/docker-hw-timelapse-recorder/main/setup.sh) | sh -s -- --uninstall

```

During uninstallation, you will be prompted and can choose whether you want to completely remove Docker and the Intel iGPU drivers from your system or leave them intact for other applications. Your saved timelapse videos and the `docker-compose.yml` file in `/opt/timelapse` are not deleted.

```
