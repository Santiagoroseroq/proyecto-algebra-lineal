using CSV, DataFrames, LinearAlgebra, Plots
using Images, FileIO

# Incluir los módulos
include("transformaciones.jl")
include("aplicacion.jl")
include("visualizacion.jl")
include("experimentos.jl")

# Usar los módulos (no necesitamos importar funciones específicas)
using .Transformaciones, .Aplicacion, .Visualizacion, .Experimentos

# ============================================================
# FUNCIONES AUXILIARES (definidas localmente)
# ============================================================
function generar_puntos_prueba()
    t = range(0, 2π, length=12)
    x_oval = 200 .+ 80 .* cos.(t)
    y_oval = 200 .+ 100 .* sin.(t)
    x_ojos = [160, 240]; y_ojos = [180, 180]
    x_boca = [170, 190, 210, 230]; y_boca = [240, 230, 230, 240]
    x_nariz = [200]; y_nariz = [210]
    x = [x_oval; x_ojos; x_boca; x_nariz]
    y = [y_oval; y_ojos; y_boca; y_nariz]
    return [x' ; y' ; ones(1, length(x))]
end

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
# CAPTURA CON CÁMARA (siempre)
# ============================================================
function capturar_con_camara()
    script_path = joinpath(@__DIR__, "capturar_y_detectar.py")
    if !isfile(script_path)
        println("ERROR: No se encontró capturar_y_detectar.py en src/")
        return false
    end

    # Comandos probados para Windows
    comandos = [
        `cmd /c start /wait py $script_path`,
        `py $script_path`,
        `python $script_path`,
        `C:\Users\VICTUSSS\AppData\Local\Programs\Python\Python313\python.exe $script_path`
    ]
    
    for cmd in comandos
        try
            println("Intentando: $cmd")
            run(cmd)
            println("Captura finalizada correctamente.")
            return isfile(ruta_csv)
        catch
            continue
        end
    end

    # Fallback manual
    println(repeat("=", 60))
    println("No se pudo ejecutar el script automáticamente.")
    println("Por favor, abre una terminal y ejecuta manualmente:")
    println("  py src/capturar_y_detectar.py")
    println("Luego presiona ENTER para continuar...")
    println(repeat("=", 60))
    readline()
    return isfile(ruta_csv)
end

# ============================================================
# INICIO: Captura con cámara
# ============================================================
println(repeat("=", 60))
println(" Abriendo cámara para capturar tu rostro...")
println(" (Asegúrate de tener la cámara conectada)")
println(repeat("=", 60))

if !capturar_con_camara()
    println("No se pudo capturar. Usando puntos sintéticos.")
    P = generar_puntos_prueba()
    img = nothing
else
    println("Captura exitosa. Cargando datos...")
    df = DataFrame(CSV.File(ruta_csv))
    P = [df.x' ; df.y' ; ones(1, length(df.x))]
    img = cargar_imagen_si_existe(ruta_img)
end

# Fallback final
if !isdefined(Main, :P)
    P = generar_puntos_prueba()
    img = nothing
end

# ============================================================
# VISUALIZACIÓN INICIAL (usando Visualizacion.graficar_rostro)
# ============================================================
if img !== nothing
    p_original = plot(img, aspect_ratio=:equal, title="Puntos sobre imagen")
    scatter!(p_original, P[1,:], P[2,:], color=:red, markersize=6, label="Puntos")
    savefig(p_original, joinpath(output_dir, "imagen_original_con_puntos.png"))
    display(p_original)
else
    p_original = Visualizacion.graficar_rostro(P; titulo="Rostro sintético")
    savefig(p_original, joinpath(output_dir, "puntos_sin_fondo.png"))
    display(p_original)
end

# ============================================================
# EXPERIMENTO 1 (usando nombres calificados)
# ============================================================
println("\nEjecutando Experimento 1: 50 rotaciones de 1°...")
try
    hist1 = Experimentos.ejecutar_experimento1(P, n=50, angulo=1.0)
    println("  hist1 generado, longitud: ", length(hist1))
    
    p1_err, p1_cond = Visualizacion.graficar_evolucion(hist1)
    savefig(p1_err, joinpath(output_dir, "exp1_error.png"))
    savefig(p1_cond, joinpath(output_dir, "exp1_condicion.png"))
    
    P_final1 = hist1[end][1]
    if img !== nothing
        p_super1 = plot(img, aspect_ratio=:equal, title="Exp1: Original (verde) vs Final (rojo ★)")
        scatter!(p_super1, P[1,:], P[2,:], color=:green, markersize=8, marker=:circle, label="Original")
        scatter!(p_super1, P_final1[1,:], P_final1[2,:], color=:red, markersize=10, marker=:star, label="Transformado")
        plot!(p_super1, P_final1[1,:], P_final1[2,:], color=:red, linewidth=2, label="")
    else
        p_super1 = plot(aspect_ratio=:equal, title="Exp1: Original vs Final")
        scatter!(p_super1, P[1,:], P[2,:], label="Original", color=:blue)
        scatter!(p_super1, P_final1[1,:], P_final1[2,:], label="Transformado", color=:red, marker=:star)
    end
    savefig(p_super1, joinpath(output_dir, "exp1_superposicion.png"))
    display(p_super1)
    
    anim1 = Visualizacion.animar_rostro(hist1, fps=5, cada=2)
    gif(anim1, joinpath(output_dir, "exp1_animacion.gif"), fps=5)
    println("GIF Exp1 guardado en output/exp1_animacion.gif")
catch e
    println("Error en Experimento 1: $e")
    println("Stacktrace:")
    Base.show_backtrace(stdout, catch_backtrace())
end

# ============================================================
# EXPERIMENTO 2 (usando nombres calificados)
# ============================================================
println("\nEjecutando Experimento 2: 30 pasos (rotación + escalado no uniforme)...")
try
    hist2 = Experimentos.ejecutar_experimento2(P, n=30, angulo=1.0, sx=1.05, sy=0.95)
    println("  hist2 generado, longitud: ", length(hist2))
    
    p2_err, p2_cond = Visualizacion.graficar_evolucion(hist2)
    savefig(p2_err, joinpath(output_dir, "exp2_error.png"))
    savefig(p2_cond, joinpath(output_dir, "exp2_condicion.png"))
    
    P_final2 = hist2[end][1]
    if img !== nothing
        p_super2 = plot(img, aspect_ratio=:equal, title="Exp2: Original (verde) vs Final (rojo ★)")
        scatter!(p_super2, P[1,:], P[2,:], color=:green, markersize=8, marker=:circle, label="Original")
        scatter!(p_super2, P_final2[1,:], P_final2[2,:], color=:red, markersize=10, marker=:star, label="Transformado")
        plot!(p_super2, P_final2[1,:], P_final2[2,:], color=:red, linewidth=2, label="")
    else
        p_super2 = plot(aspect_ratio=:equal, title="Exp2: Original vs Final")
        scatter!(p_super2, P[1,:], P[2,:], label="Original", color=:blue)
        scatter!(p_super2, P_final2[1,:], P_final2[2,:], label="Transformado", color=:red, marker=:star)
    end
    savefig(p_super2, joinpath(output_dir, "exp2_superposicion.png"))
    display(p_super2)
    
    anim2 = Visualizacion.animar_rostro(hist2, fps=5, cada=2)
    gif(anim2, joinpath(output_dir, "exp2_animacion.gif"), fps=5)
    println("GIF Exp2 guardado en output/exp2_animacion.gif")
catch e
    println("Error en Experimento 2: $e")
    println("Stacktrace:")
    Base.show_backtrace(stdout, catch_backtrace())
end

println("\nTodo listo. Revisa la carpeta 'output'.")
println("Archivos esperados:")
println("   - exp1_error.png / exp1_condicion.png")
println("   - exp1_superposicion.png / exp1_animacion.gif")
println("   - exp2_error.png / exp2_condicion.png")
println("   - exp2_superposicion.png / exp2_animacion.gif")