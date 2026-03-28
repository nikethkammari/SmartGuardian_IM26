from ultralytics import YOLO
model = YOLO("backend/helmet/weights/best (1).pt")
for id, name in model.names.items():
    print(f"ID {id}: '{name}'")
