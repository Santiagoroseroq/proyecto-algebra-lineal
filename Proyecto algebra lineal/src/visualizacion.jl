module Visualizacion

using Plots
using ..Aplicacion

export graficar_rostro, graficar_evolucion, animar_rostro

function graficar_rostro(P; titulo="")
    x = P[1, :]
    y = P[2, :]
    p = scatter(x, y, aspect_ratio=:equal, title=titulo, 
                xlabel="x", ylabel="y", label="Puntos")
    plot!(p, x, y, label="Rostro", linewidth=2)
    return p
end

function graficar_evolucion(historial)
    errores = [h[2] for h in historial]
    kappas = [h[3] for h in historial]
    pasos = eachindex(historial)   # ✅ CAMBIO AQUÍ

    p1 = plot(pasos, errores, yaxis=:log, label="Error ortogonalidad",
              xlabel="Paso", ylabel="Error", title="Error de ortogonalidad", legend=:top)
    p2 = plot(pasos, kappas, yaxis=:log, label="Nº condición",
              xlabel="Paso", ylabel="κ", title="Número de condición", legend=:top)
    return p1, p2
end

function animar_rostro(historial; fps=5, cada=2)
    anim = @gif for i in eachindex(historial)   
        P_act = historial[i][1]
        scatter(P_act[1, :], P_act[2, :], aspect_ratio=:equal,
                title="Paso $i", legend=false, xlabel="x", ylabel="y")
    end every cada
    return anim
end

end  