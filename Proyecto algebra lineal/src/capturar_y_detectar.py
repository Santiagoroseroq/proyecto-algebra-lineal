import cv2
import pandas as pd
import os
import urllib.request

CAMERA_INDEX = 0
OUTPUT_CSV = "data/rostro.csv"
OUTPUT_IMAGE = "data/rostro.jpg"
XML_PATH = "haarcascade_frontalface_default.xml"

def descargar_xml():
    if not os.path.exists(XML_PATH):
        url = "https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/haarcascade_frontalface_default.xml"
        print("Descargando clasificador...")
        try:
            urllib.request.urlretrieve(url, XML_PATH)
            print("Descarga completada.")
        except Exception as e:
            print("Error al descargar:", e)
            return False
    return True

def mostrar_imagen_con_puntos(imagen, puntos):
    """Muestra la imagen con los puntos dibujados y espera una tecla."""
    img_copy = imagen.copy()
    for i, (x, y) in enumerate(puntos):
        cv2.circle(img_copy, (x, y), 6, (0, 255, 0), -1)
        cv2.putText(img_copy, f"{i+1}", (x-10, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0,255,0), 1)
    cv2.imshow("Imagen capturada con puntos - Presiona cualquier tecla para continuar", img_copy)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

def capturar_foto():
    if not descargar_xml():
        print("No se pudo obtener el clasificador.")
        return None

    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        print("No se pudo abrir la camara.")
        return None

    face_cascade = cv2.CascadeClassifier(XML_PATH)

    print("Presiona ESPACIO para capturar, ESC para salir.")
    print("Coloca tu rostro dentro del recuadro guia.")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Error al leer el frame.")
            break

        h, w, _ = frame.shape
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.3, 5)
        cara_detectada = len(faces) > 0

        if cara_detectada:
            cv2.rectangle(frame, (int(w*0.1), int(h*0.1)), (int(w*0.9), int(h*0.9)), (0, 255, 0), 2)
            cv2.putText(frame, "ROSTRO DETECTADO - Presiona ESPACIO", (20, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,0), 2)
        else:
            cv2.rectangle(frame, (int(w*0.1), int(h*0.1)), (int(w*0.9), int(h*0.9)), (0, 0, 255), 2)
            cv2.putText(frame, "ROSTRO NO DETECTADO - Colocate bien", (20, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,0,255), 2)

        cv2.imshow("Captura de rostro", frame)

        key = cv2.waitKey(1) & 0xFF
        if key == 32:
            if cara_detectada:
                os.makedirs("data", exist_ok=True)
                cv2.imwrite(OUTPUT_IMAGE, frame)
                print("Foto guardada como", OUTPUT_IMAGE)

                x, y, w_face, h_face = faces[0]
                puntos = [
                    (x + w_face//2, y + int(h_face*0.1)),
                    (x + int(w_face*0.2), y + int(h_face*0.3)),
                    (x + int(w_face*0.35), y + int(h_face*0.3)),
                    (x + int(w_face*0.65), y + int(h_face*0.3)),
                    (x + int(w_face*0.8), y + int(h_face*0.3)),
                    (x + w_face//2, y + int(h_face*0.55)),
                    (x + int(w_face*0.35), y + int(h_face*0.7)),
                    (x + int(w_face*0.65), y + int(h_face*0.7)),
                    (x + w_face//2, y + h_face - int(h_face*0.05))
                ]
                df = pd.DataFrame(puntos, columns=["x", "y"])
                df.to_csv(OUTPUT_CSV, index=False)
                print("Puntos guardados en", OUTPUT_CSV)

                # Mostrar la imagen capturada con los puntos
                mostrar_imagen_con_puntos(frame, puntos)

                cap.release()
                cv2.destroyAllWindows()
                return frame
            else:
                print("No hay rostro detectado. Intentelo de nuevo.")
        elif key == 27:
            print("Captura cancelada.")
            cap.release()
            cv2.destroyAllWindows()
            return None

    cap.release()
    cv2.destroyAllWindows()
    return None

if __name__ == "__main__":
    print("Iniciando camara...")
    frame = capturar_foto()
    if frame is None:
        print("No se capturo foto.")
    else:
        print("Captura completada. Ahora ejecute main.jl en Julia.")