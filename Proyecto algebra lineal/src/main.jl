using CSV, DataFrames, LinearAlgebra, Plots
using Images, FileIO

# Incluir los módulos
include("transformaciones.jl")
include("aplicacion.jl")
include("visualizacion.jl")
include("Experimentos.jl")

using .Transformaciones, .Aplicacion, .Visualizacion, .Experimentos

# ============================================================
# FUNCIONES AUXILIARES
# ============================================================
function cargar_imagen_si_existe(ruta)
    if isfile(ruta)
        try
            img = load(ruta)
            return RGB.(img)
        catch
            return nothing
        end
    else
        return nothing
    end
end

# ============================================================
# CONFIGURACIÓN DE CARPETAS
# ============================================================
output_dir = joinpath(@__DIR__, "../output")
if !isdir(output_dir)
    mkdir(output_dir)
end

ruta_csv = joinpath(@__DIR__, "../data/rostro.csv")
ruta_img = joinpath(@__DIR__, "../data/rostro.jpg")

# ============================================================
# CAPTURA CON CÁMARA (obligatoria)
# ============================================================
function capturar_con_camara()
    script_path = joinpath(@__DIR__, "capturar_y_detectar.py")
    if !isfile(script_path)
        error("No se encontró capturar_y_detectar.py en src/")
    end

    comandos = [
        `python $script_path`,
        `py $script_path`,
        `C:\Users\VICTUSSS\AppData\Local\Programs\Python\Python313\python.exe $script_path`
    ]
    
    for cmd in comandos
        try
            println("Ejecutando: $cmd")
            run(cmd)
            println("Captura finalizada.")
            return isfile(ruta_csv)
        catch
            continue
        end
    end

    error("No se pudo ejecutar el script Python. Asegúrate de tener Python instalado y la cámara conectada.")
end

println("="^60)
println("INICIANDO CAPTURA DE ROSTRO")
println("="^60)

if !capturar_con_camara()
    error("No se generó el archivo rostro.csv. Verifica la captura.")
else
    println("Captura exitosa. Cargando datos...")
    df = DataFrame(CSV.File(ruta_csv))
    P = [df.x' ; df.y' ; ones(1, length(df.x))]
    println("Puntos cargados: $(size(P,2))")
    img = cargar_imagen_si_existe(ruta_img)
end

# ============================================================
# VISUALIZACIÓN INICIAL
# ============================================================
println("Generando visualización inicial...")
if img !== nothing
    p_original = plot(img, aspect_ratio=:equal, title="Puntos sobre imagen")
    scatter!(p_original, P[1,:], P[2,:], color=:red, markersize=6, label="Puntos")
    savefig(p_original, joinpath(output_dir, "imagen_original_con_puntos.png"))
    display(p_original)
else
    error("No se pudo cargar la imagen. Asegúrate de que rostro.jpg exista en data/")
end

# ============================================================
# EXPERIMENTO 1
# ============================================================
println("\nEjecutando Experimento 1: 50 rotaciones de 1 grado...")
hist1 = Experimentos.ejecutar_experimento1(P, n=50, angulo=1.0)
println("  hist1 generado, longitud: ", length(hist1))

p1_err, p1_cond = Visualizacion.graficar_evolucion(hist1)
savefig(p1_err, joinpath(output_dir, "exp1_error.png"))
savefig(p1_cond, joinpath(output_dir, "exp1_condicion.png"))

P_final1 = hist1[end][1]
p_super1 = plot(img, aspect_ratio=:equal, title="Exp1: Original (verde) vs Final (rojo *)")
scatter!(p_super1, P[1,:], P[2,:], color=:green, markersize=8, marker=:circle, label="Original")
scatter!(p_super1, P_final1[1,:], P_final1[2,:], color=:red, markersize=10, marker=:star, label="Transformado")
plot!(p_super1, P_final1[1,:], P_final1[2,:], color=:red, linewidth=2, label="")
savefig(p_super1, joinpath(output_dir, "exp1_superposicion.png"))
display(p_super1)

anim1 = Visualizacion.animar_rostro(hist1, fps=5, cada=2)
gif(anim1, joinpath(output_dir, "exp1_animacion.gif"), fps=5)
println("GIF Exp1 guardado en output/exp1_animacion.gif")

# ============================================================
# EXPERIMENTO 2
# ============================================================
println("\nEjecutando Experimento 2: 30 pasos (rotacion + escalado no uniforme)...")
hist2 = Experimentos.ejecutar_experimento2(P, n=30, angulo=1.0, sx=1.05, sy=0.95)
println("  hist2 generado, longitud: ", length(hist2))

p2_err, p2_cond = Visualizacion.graficar_evolucion(hist2)
savefig(p2_err, joinpath(output_dir, "exp2_error.png"))
savefig(p2_cond, joinpath(output_dir, "exp2_condicion.png"))

P_final2 = hist2[end][1]
p_super2 = plot(img, aspect_ratio=:equal, title="Exp2: Original (verde) vs Final (rojo *)")
scatter!(p_super2, P[1,:], P[2,:], color=:green, markersize=8, marker=:circle, label="Original")
scatter!(p_super2, P_final2[1,:], P_final2[2,:], color=:red, markersize=10, marker=:star, label="Transformado")
plot!(p_super2, P_final2[1,:], P_final2[2,:], color=:red, linewidth=2, label="")
savefig(p_super2, joinpath(output_dir, "exp2_superposicion.png"))
display(p_super2)

anim2 = Visualizacion.animar_rostro(hist2, fps=5, cada=2)
gif(anim2, joinpath(output_dir, "exp2_animacion.gif"), fps=5)
println("GIF Exp2 guardado en output/exp2_animacion.gif")

# ============================================================
# ANALISIS AVANZADO
# ============================================================
println("\nGenerando analisis avanzado (area, dashboard, SVD)...")

function area_poligono(P)
    n = size(P, 2)
    x = P[1, :]
    y = P[2, :]
    s = 0.0
    for i in 1:n-1
        s += x[i]*y[i+1] - x[i+1]*y[i]
    end
    s += x[n]*y[1] - x[1]*y[n]
    return 0.5 * abs(s)
end

function calcular_metricas(hist)
    kappa = [h[3] for h in hist]
    err = [h[2] for h in hist]
    areas = [area_poligono(h[1][1:2,:]) for h in hist]
    area_rel = areas / areas[1]
    return kappa, err, area_rel
end

kappa1, err1, area1 = calcular_metricas(hist1)
kappa2, err2, area2 = calcular_metricas(hist2)

# 🔑 Cambio CLAVE: definimos pasos separados
pasos1 = 1:length(hist1)   # 50 elementos
pasos2 = 1:length(hist2)   # 60 elementos

p1 = plot(pasos1, kappa1, yaxis=:log, label="Exp1 (Rot)", lw=2, color=:blue)
plot!(p1, pasos2, kappa2, yaxis=:log, label="Exp2 (Rot+Esc)", lw=2, linestyle=:dash, color=:red)
title!(p1, "Numero de Condicion")

p2 = plot(pasos1, max.(err1, 1e-16), yaxis=:log, label="Exp1", lw=2, color=:blue)
plot!(p2, pasos2, max.(err2, 1e-16), yaxis=:log, label="Exp2", lw=2, linestyle=:dash, color=:red)
title!(p2, "Error de Ortogonalidad")

p3 = plot(pasos1, area1, label="Exp1", lw=2, color=:blue)
plot!(p3, pasos2, area2, label="Exp2", lw=2, linestyle=:dash, color=:red)
plot!(p3, [1, max(last(pasos1), last(pasos2))], [1, 1], label="Area ideal", linestyle=:dot, color=:black)
title!(p3, "Area Relativa")

labels = ["kappa (log10)", "Error (log10)", "Area Rel"]
val1 = [log10(kappa1[end]), log10(err1[end]), area1[end]]
val2 = [log10(kappa2[end]), log10(err2[end]), area2[end]]
p4 = bar(labels, [val1 val2], legend=:none, title="Metricas finales", bar_width=0.6)
dashboard = plot(p1, p2, p3, p4, layout=(2,2), size=(1000, 800))
savefig(dashboard, joinpath(output_dir, "dashboard_avanzado.png"))
display(dashboard)

function dibujar_svd(P_final, T_acum; titulo="SVD - Direcciones de deformacion")
    A = T_acum[1:2, 1:2]
    U, S, V = svd(A)
    escala = 40.0
    centro = mean(P_final[1:2, :], dims=2)
    v1 = V[:, 1] * S[1] * escala / 2
    v2 = V[:, 2] * S[2] * escala * 3
    p = plot(aspect_ratio=:equal, title=titulo, xlabel="x", ylabel="y")
    scatter!(p, P_final[1,:], P_final[2,:], color=:blue, label="Rostro final")
    plot!(p, P_final[1,:], P_final[2,:], color=:blue, alpha=0.5, label="")
    quiver!(p, [centro[1]], [centro[2]], quiver=([v1[1]], [v1[2]]), color=:red, linewidth=3, label="sigma1 (estiramiento)")
    quiver!(p, [centro[1]], [centro[2]], quiver=([v2[1]], [v2[2]]), color=:blue, linewidth=3, label="sigma2 (colapso)")
    return p
end

T_final2 = hist2[end][4]
p_svd = dibujar_svd(hist2[end][1], T_final2)
savefig(p_svd, joinpath(output_dir, "svd_vectores_exp2.png"))
display(p_svd)

println("\nCOMPARATIVA FINAL:")
println("=" * 60)
println("Metrica               | Exp1 (Rot)     | Exp2 (Rot+Esc)")
println("-" * 60)
println("kappa final           | $(round(kappa1[end], digits=2))     | $(round(kappa2[end], digits=2))")
println("Error Ort. final      | $(round(err1[end], sigdigits=3)) | $(round(err2[end], sigdigits=3))")
println("Area Relativa final   | $(round(area1[end], digits=4))    | $(round(area2[end], digits=4))")
println("=" * 60)

println("\nTodo listo. Revisa la carpeta 'output'.")
println("Archivos generados:")
println("   - exp1_error.png / exp1_condicion.png")
println("   - exp1_superposicion.png / exp1_animacion.gif")
println("   - exp2_error.png / exp2_condicion.png")
println("   - exp2_superposicion.png / exp2_animacion.gif")
println("   - dashboard_avanzado.png")
println("   - svd_vectores_exp2.png")