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
    """Starts a new FFmpeg process and handles dynamic folder creation."""
    now = datetime.datetime.now()
    
    # 1. Construct hierarchical path: YYYY/MM/DD/HH
    folder_path = os.path.join(
        BASE_OUTPUT_DIR,
        now.strftime("%Y"),
        now.strftime("%m"),
        now.strftime("%d"),
        now.strftime("%H")
    )
    
    # Ensure the directory structure exists before writing to it
    os.makedirs(folder_path, exist_ok=True)
    
    # 2. Construct filename with the static prefix
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
    return subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)

def main():
    ffmpeg_process = start_ffmpeg_process()
    frames_written = 0
    next_time = time.time()

    while True:
        try:
            response = requests.get(IMAGE_URL, timeout=0.8)
            response.raise_for_status()
            
            ffmpeg_process.stdin.write(response.content)
            ffmpeg_process.stdin.flush()
            frames_written += 1
            
        except requests.RequestException as e:
            print(f"Failed to fetch image: {e}")
            
        if frames_written >= 3600:
            print("1 hour reached. Finalizing video...")
            ffmpeg_process.stdin.close()
            ffmpeg_process.wait() 
            
            ffmpeg_process = start_ffmpeg_process()
            frames_written = 0

        next_time += 1.0
        sleep_time = next_time - time.time()
        if sleep_time > 0:
            time.sleep(sleep_time)

if __name__ == "__main__":
    main()