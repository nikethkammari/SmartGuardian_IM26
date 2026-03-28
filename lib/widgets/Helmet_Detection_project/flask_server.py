# -*- coding: utf-8 -*-
import cv2
import math
import cvzone
from ultralytics import YOLO
import os
import time
import threading
from flask import Flask, Response, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Configuration
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "weights", "best (1).pt")
SCREENSHOTS_DIR = os.path.join(BASE_DIR, "screenshots")

# Load YOLO model
model = YOLO(MODEL_PATH)
classNames = ['With Helmet', 'Helmet Notfound']

# Shared State
latest_frame = None
helmet_present = False
frame_lock = threading.Lock()

# Background Detection Thread
def detection_loop():
    global latest_frame, helmet_present

    cap = cv2.VideoCapture(0)
    frame_count = 0
    skip_frames = 1
    last_results = []

    while True:
        success, img = cap.read()
        if not success:
            time.sleep(0.05)
            continue

        img = cv2.resize(img, (640, 480))

        if frame_count % (skip_frames + 1) == 0:
            results = model(img, stream=True, imgsz=320)
            last_results = list(results)

        frame_count += 1

        detected = False
        for r in last_results:
            for box in r.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                conf = math.ceil((box.conf[0] * 100)) / 100
                cls = int(box.cls[0])

                if classNames[cls] == 'With Helmet':
                    detected = True

                w, h = x2 - x1, y2 - y1
                cvzone.cornerRect(img, (x1, y1, w, h))
                cvzone.putTextRect(img, f'{classNames[cls]} {conf}',
                                   (max(0, x1), max(35, y1)), scale=1, thickness=1)

        # Update shared state
        with frame_lock:
            helmet_present = detected
            latest_frame = img.copy()

# MJPEG Stream Generator
def generate_stream():
    while True:
        with frame_lock:
            frame = latest_frame

        if frame is None:
            time.sleep(0.05)
            continue

        (flag, encoded) = cv2.imencode(".jpg", frame)
        if not flag:
            continue

        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + bytearray(encoded) + b'\r\n')

        time.sleep(0.033)  # ~30 fps max

# Routes
@app.route('/video_feed')
def video_feed():
    print(f"Request: /video_feed from {threading.current_thread().name}")
    return Response(generate_stream(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/detection_status')
def detection_status():
    with frame_lock:
        status = helmet_present
    return jsonify({"helmet_present": status, "timestamp": time.time()})

@app.route('/reset_detection', methods=['POST'])
def reset_detection():
    return jsonify({"status": "ok"})

# Start
if __name__ == "__main__":
    if not os.path.exists(SCREENSHOTS_DIR):
        os.makedirs(SCREENSHOTS_DIR)

    # Start detection in background thread
    t = threading.Thread(target=detection_loop, daemon=True)
    t.start()

    print(f"Flask server running at http://0.0.0.0:5000")
    print(f"  Stream:  http://127.0.0.1:5000/video_feed")
    print(f"  Status:  http://127.0.0.1:5000/detection_status")
    print(f"  Weights: {MODEL_PATH}")

    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
