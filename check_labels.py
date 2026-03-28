from ultralytics import YOLO
import sys

try:
    model = YOLO("backend/helmet/weights/best (1).pt")
    print("Classes:", model.names)
except Exception as e:
    print("Error:", e)
