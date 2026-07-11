import cv2
import mediapipe as mp
import pandas as pd
import numpy as np
import sys

# Inicializar MediaPipe FaceMesh
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1, min_detection_confidence=0.5)

# Índices de los puntos clave que nos interesan (según MediaPipe)
# Referencia: https://github.com/google/mediapipe/blob/master/mediapipe/modules/face_geometry/data/geometry_pipeline_metadata.json
LANDMARK_INDICES = {
    "frente": [10, 338, 297, 332],  # centro de la frente (promedio)
    "ojo_izquierdo_externo": [33],
    "ojo_izquierdo_interno": [133],
    "ojo_derecho_interno": [362],
    "ojo_derecho_externo": [263],
    "nariz_punta": [1],
    "boca_izquierda": [61],
    "boca_derecha": [291],
    "menton": [152]
}

def detectar_puntos(imagen_path):
    # Leer imagen
    img = cv2.imread(imagen_path)
    if img is None:
        print(f"❌ Error: No se pudo cargar la imagen {imagen_path}")
        return None
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    h, w, _ = img.shape
    
    # Detectar caras
    results = face_mesh.process(img_rgb)
    if not results.multi_face_landmarks:
        print("❌ No se detectó ningún rostro en la imagen.")
        return None
    
    # Tomar la primera cara
    landmarks = results.multi_face_landmarks[0].landmark
    
    # Extraer coordenadas (x, y) en píxeles
    puntos = {}
    for nombre, indices in LANDMARK_INDICES.items():
        # Si hay varios índices, promediamos (para la frente)
        xs = []
        ys = []
        for idx in indices:
            x = landmarks[idx].x * w
            y = landmarks[idx].y * h
            xs.append(x)
            ys.append(y)
        puntos[nombre] = (int(np.mean(xs)), int(np.mean(ys)))
    
    # Ordenar los puntos según el orden que espera nuestro código de Julia
    # (frente, ojo_izquierdo_externo, ojo_izquierdo_interno, ojo_derecho_interno, ojo_derecho_externo, nariz_punta, boca_izquierda, boca_derecha, menton)
    orden = ["frente", "ojo_izquierdo_externo", "ojo_izquierdo_interno", "ojo_derecho_interno", "ojo_derecho_externo", "nariz_punta", "boca_izquierda", "boca_derecha", "menton"]
    puntos_ordenados = [puntos[nombre] for nombre in orden]
    
    # Guardar en CSV
    df = pd.DataFrame(puntos_ordenados, columns=["x", "y"])
    df.to_csv("rostro.csv", index=False)
    print(f"✅ Puntos guardados en rostro.csv: {len(puntos_ordenados)} puntos.")
    print("📁 Archivo generado en el directorio actual.")
    return puntos_ordenados

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python detectar_puntos_faciales.py <ruta_de_la_imagen>")
        print("Ejemplo: python detectar_puntos_faciales.py rostro.jpg")
        sys.exit(1)
    imagen_path = sys.argv[1]
    detectar_puntos(imagen_path)