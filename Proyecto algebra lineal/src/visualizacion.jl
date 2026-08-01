module Visualizacion

using Plots

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
    pasos = 1:length(historial)

    p1 = plot(pasos, errores, yaxis=:log, label="Error ortogonalidad",
              xlabel="Paso", ylabel="Error", title="Error de ortogonalidad", legend=:top)
    p2 = plot(pasos, kappas, yaxis=:log, label="Nº condición",
              xlabel="Paso", ylabel="κ", title="Número de condición", legend=:top)
    return p1, p2
end

# 🔧 CORREGIDO: ejes fijos + líneas que conectan los puntos (para reconocer el rostro)
function animar_rostro(historial; fps=5, cada=1)
    # Calculamos límites globales para que la "cámara" no se mueva
    todos_x = vcat([h[1][1, :] for h in historial]...)
    todos_y = vcat([h[1][2, :] for h in historial]...)
    xlims = (minimum(todos_x) - 20, maximum(todos_x) + 20)
    ylims = (minimum(todos_y) - 20, maximum(todos_y) + 20)

    # La animación se construye explícitamente con un bucle for y savefig
    # (más control que @gif)
    anim = @animate for i in 1:cada:length(historial)
        P_act = historial[i][1]
        x = P_act[1, :]
        y = P_act[2, :]
        
        # Dibujar puntos y conectarlos con líneas (para ver la forma facial)
        scatter(x, y, aspect_ratio=:equal,
                title="Paso $i", legend=false, xlabel="x", ylabel="y",
                xlims=xlims, ylims=ylims,   # ¡ejes fijos!
                markersize=6, color=:blue)
        plot!(x, y, color=:blue, linewidth=2, alpha=0.7)
    end

    # Guardamos el GIF con fps explícito
    gif(anim, joinpath(@__DIR__, "../output/animacion_temporal.gif"), fps=fps)
    println("Animación guardada en output/animacion_temporal.gif")
    return anim
end

end