module Imagen

using Images, FileIO, Plots

export cargar_imagen, mostrar_puntos_sobre_imagen

function cargar_imagen(ruta)
    img = load(ruta)
    return RGB.(img)
end

function mostrar_puntos_sobre_imagen(img, P; titulo="")
    x = P[1, :]
    y = P[2, :]
    p = plot(img, aspect_ratio=:equal, title=titulo)
    scatter!(p, x, y, color=:red, markersize=8, label="Puntos marcadores")
    plot!(p, x, y, color=:blue, linewidth=2, label="Rostro")
    return p
end

end