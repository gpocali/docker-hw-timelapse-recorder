import time
import requests
import subprocess
import os
import datetime

# Configuration from Environment Variables
IMAGE_URL = os.environ.get("IMAGE_URL", "http://your-source-ip/image.jpg")
BASE_OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/output")
OUTPUT_FPS = os.environ.get("OUTPUT_FPS", "30")
FILE_PREFIX = os.environ.get("FILE_PREFIX", "timelapse")

def start_ffmpeg_process():
    """Starts a new FFmpeg process and returns the process and its starting hour."""
    now = datetime.datetime.now()
    
    # Construct hierarchical path: YYYY/MM/DD/HH
    folder_path = os.path.join(
        BASE_OUTPUT_DIR,
        now.strftime("%Y"),
        now.strftime("%m"),
        now.strftime("%d"),
        now.strftime("%H")
    )
    
    # Ensure the directory structure exists
    os.makedirs(folder_path, exist_ok=True)
    
    # Construct filename with the static prefix
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    output_filename = os.path.join(folder_path, f"{FILE_PREFIX}_{timestamp}.mkv")
    
    cmd = [
        "ffmpeg",
        "-y",                      
        "-f", "image2pipe",        
        "-vcodec", "mjpeg",        
        "-framerate", OUTPUT_FPS,         
        "-i", "-",                 
        
        # Intel Hardware Acceleration (VAAPI)
        "-vaapi_device", "/dev/dri/renderD128", 
        
        # Scale to even dimensions and upload to the GPU
        "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2,format=nv12,hwupload",
        
        # Encode using Intel H.264 HW encoder
        "-c:v", "h264_vaapi",                   
        "-profile:v", "main",      
        "-qp", "25",                            
        
        output_filename
    ]
    
    print(f"Starting new video file: {output_filename}")
    process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    
    # Return the process AND the integer of the current hour (0-23)
    return process, now.hour

def main():
    ffmpeg_process, active_hour = start_ffmpeg_process()
    next_time = time.time()

    while True:
        now = datetime.datetime.now()
        
        # Check if the wall clock hour has rolled over (e.g., from 2 to 3)
        if now.hour != active_hour:
            print(f"Top of the hour reached ({now.strftime('%H:00')}). Segmenting video...")
            ffmpeg_process.stdin.close()
            ffmpeg_process.wait() 
            
            # Start the new process and update the active_hour
            ffmpeg_process, active_hour = start_ffmpeg_process()

        try:
            response = requests.get(IMAGE_URL, timeout=0.8)
            response.raise_for_status()
            
            ffmpeg_process.stdin.write(response.content)
            ffmpeg_process.stdin.flush()
            
        except requests.RequestException as e:
            print(f"Failed to fetch image: {e}")
            # If it fails, FFmpeg just waits. We no longer care about dropped frames 
            # throwing off the segment timing.
            
        # Precision sleep to maintain exactly 1 second intervals
        next_time += 1.0
        sleep_time = next_time - time.time()
        if sleep_time > 0:
            time.sleep(sleep_time)

if __name__ == "__main__":
    main()