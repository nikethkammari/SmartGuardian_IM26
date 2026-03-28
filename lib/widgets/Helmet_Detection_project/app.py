import cv2
import math
import cvzone   #type: ignore
from ultralytics import YOLO   #type: ignore
import os
import time
import pyttsx3  #type: ignore

#video capture 
cap = cv2.VideoCapture(0)

model = YOLO("weights/best (1).pt")
classNames = ['With Helmet', 'Helmet Notfound']

engine = pyttsx3.init()
engine.setProperty('rate', 150) # Speed of speech

if not os.path.exists('screenshots'):
    os.makedirs('screenshots')

frame_count = 0
skip_frames = 2  
last_results = []

last_alert_time = 0
alert_cooldown = 5 # seconds

while True:
    success, img = cap.read()
    if not success:
        print("Failed to read from webcam. Make sure it's connected and not used by another app.")
        break
    
    
    img = cv2.resize(img, (640, 480))
    
   
    if frame_count % (skip_frames + 1) == 0:
        
        results = model(img, stream=True, imgsz=320) 
        last_results = list(results)
    
    frame_count += 1
    helmet_detected = False

    
    for r in last_results:
        boxes = r.boxes
        for box in boxes:
            x1, y1, x2, y2 = box.xyxy[0]
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)

            conf = math.ceil((box.conf[0] * 100)) / 100
            cls = int(box.cls[0])
            
            
            if classNames[cls] == 'With Helmet':
                helmet_detected = True
            
            
            w, h = x2 - x1, y2 - y1
            cvzone.cornerRect(img, (x1, y1, w, h))
            cvzone.putTextRect(img, f'{classNames[cls]} {conf}', (max(0, x1), max(35, y1)), scale=1, thickness=1)

   
    current_time = time.time()
    if helmet_detected and (current_time - last_alert_time > alert_cooldown):
        
        timestamp = time.strftime("%Y%m%d-%H%M%S")
        screenshot_path = f"screenshots/helmet_detected_{timestamp}.jpg"
        cv2.imwrite(screenshot_path, img)
        print(f"Screenshot saved: {screenshot_path}")
        
        
        try:
            engine.say("hello buddy...! You can drive safely")
            engine.runAndWait()
        except:
            pass 
        
        last_alert_time = current_time

    cv2.imshow("Image", img)
    
    key = cv2.waitKey(1)
    if key & 0xFF == ord('q') or key == 27:
        break


cap.release()
cv2.destroyAllWindows()


try:
    engine.stop()
except:
    pass
del engine