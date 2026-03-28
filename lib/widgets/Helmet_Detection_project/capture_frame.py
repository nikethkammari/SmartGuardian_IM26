import cv2
import sys

cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Cannot open camera")
    sys.exit()

ret, frame = cap.read()
if ret:
    cv2.imwrite("webcam_frame.jpg", frame)
    print("Frame saved successfully")
else:
    print("Can't receive frame")

cap.release()
