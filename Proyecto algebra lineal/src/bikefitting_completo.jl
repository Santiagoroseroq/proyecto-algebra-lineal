module BikeFittingCompleto

using LinearAlgebra, Plots

export calcular_posiciones, medidas_salida, sensitivity_matrix,
       analyze_bike_fitting, plot_kappa_heatmap, plot_bike_geometry

# ================================================================
# GEOMETRIA COMPLETA
# ================================================================

function calcular_posiciones(a_s, h_s, a_m, h_m;
                             femur=0.42, tibia=0.40, pie=0.10,
                             torso=0.50, brazo=0.35, biela=0.17)
    Hx, Hy = a_s, h_s
    Mx, My = a_m, h_m
    Sx, Sy = Mx, My
    Px, Py = 0.0, -biela

    d = sqrt((Px - Hx)^2 + (Py - Hy)^2)
    if d > femur + tibia || d < abs(femur - tibia)
        Kx, Ky = a_s + 0.3, h_s - 0.3
    else
        ex = (Px - Hx) / d
        ey = (Py - Hy) / d
        p = (femur^2 - tibia^2 + d^2) / (2d)
        q = sqrt(max(0.0, femur^2 - p^2))
        Kx1 = Hx + p*ex - q*ey
        Ky1 = Hy + p*ey + q*ex
        Kx2 = Hx + p*ex + q*ey
        Ky2 = Hy + p*ey - q*ex
        if Kx1 > Kx2
            Kx, Ky = Kx1, Ky1
        else
            Kx, Ky = Kx2, Ky2
        end
    end

    Ax, Ay = 0.0, -biela + pie

    return Dict(
        :cadera => (Hx, Hy),
        :rodilla => (Kx, Ky),
        :tobillo => (Ax, Ay),
        :hombro => (Sx, Sy),
        :manillar => (Mx, My),
        :pedal => (Px, Py)
    )
end

function medidas_salida(a_s, h_s, a_m, h_m; kwargs...)
    pos = calcular_posiciones(a_s, h_s, a_m, h_m; kwargs...)
    Hx, Hy = pos[:cadera]
    Kx, Ky = pos[:rodilla]
    Px, Py = pos[:pedal]
    Sx, Sy = pos[:hombro]

    v1 = (Hx - Kx, Hy - Ky)
    v2 = (Px - Kx, Py - Ky)
    n1 = sqrt(v1[1]^2 + v1[2]^2)
    n2 = sqrt(v2[1]^2 + v2[2]^2)
    cos_ang = clamp(dot(v1, v2) / (n1 * n2), -1.0, 1.0)
    ang_rodilla = rad2deg(acos(cos_ang))

    kops = Kx - Px

    v_tronco = (Sx - Hx, Sy - Hy)
    ang_tronco = rad2deg(atan(v_tronco[2], v_tronco[1]))

    return [ang_rodilla, kops, ang_tronco]
end

function sensitivity_matrix(a_s, h_s, a_m, h_m; kwargs...)
    delta = 0.001
    A = zeros(3, 4)

    y_plus = medidas_salida(a_s + delta, h_s, a_m, h_m; kwargs...)
    y_minus = medidas_salida(a_s - delta, h_s, a_m, h_m; kwargs...)
    A[:, 1] = (y_plus - y_minus) / (2delta)

    y_plus = medidas_salida(a_s, h_s + delta, a_m, h_m; kwargs...)
    y_minus = medidas_salida(a_s, h_s - delta, a_m, h_m; kwargs...)
    A[:, 2] = (y_plus - y_minus) / (2delta)

    y_plus = medidas_salida(a_s, h_s, a_m + delta, h_m; kwargs...)
    y_minus = medidas_salida(a_s, h_s, a_m - delta, h_m; kwargs...)
    A[:, 3] = (y_plus - y_minus) / (2delta)

    y_plus = medidas_salida(a_s, h_s, a_m, h_m + delta; kwargs...)
    y_minus = medidas_salida(a_s, h_s, a_m, h_m - delta; kwargs...)
    A[:, 4] = (y_plus - y_minus) / (2delta)

    return A
end

function analyze_bike_fitting(a_s, h_s, a_m, h_m; verbose=true, kwargs...)
    A = sensitivity_matrix(a_s, h_s, a_m, h_m; kwargs...)
    kappa = cond(A)
    U, S, V = svd(A)
    y = medidas_salida(a_s, h_s, a_m, h_m; kwargs...)
    ang_rodilla, kops, ang_tronco = y

    if verbose
        println("\n" * "="^80)
        println("BIKE FITTING COMPLETO")
        println("="^80)
        println("Medidas antropometricas:")
        println("   Femur = $(round(get(kwargs, :femur, 0.42)*100, digits=1)) cm")
        println("   Tibia = $(round(get(kwargs, :tibia, 0.40)*100, digits=1)) cm")
        println("   Torso = $(round(get(kwargs, :torso, 0.50)*100, digits=1)) cm")
        println("   Brazo (hombro-muñeca) = $(round(get(kwargs, :brazo, 0.35)*100, digits=1)) cm")
        println("   Pie = $(round(get(kwargs, :pie, 0.10)*100, digits=1)) cm")
        println("   Biela = $(round(get(kwargs, :biela, 0.17)*100, digits=1)) cm")
        println("\nConfiguracion actual:")
        println("   Altura sillin (h_s) = $(round(h_s*100, digits=1)) cm")
        println("   Avance sillin (a_s) = $(round(a_s*100, digits=1)) cm")
        println("   Altura manillar (h_m) = $(round(h_m*100, digits=1)) cm")
        println("   Alcance manillar (a_m) = $(round(a_m*100, digits=1)) cm")
        println("\nEstado biomecanico:")
        println("   Angulo rodilla (BDC) = $(round(ang_rodilla, digits=1))°")
        println("   KOPS = $(round(kops*100, digits=1)) cm")
        println("   Angulo tronco (horizontal) = $(round(ang_tronco, digits=1))°")
        println("\nMatriz de sensibilidad A (3x4):")
        display(A)
        println("\nNumero de condicion espectral: κ(A) = $(round(kappa, digits=4))")

        if kappa > 1e4
            println("\nCRITICO: κ > 10^4")
            println("   El sistema es muy sensible a errores de medicion.")
            println("   Medicion no confiable. Revisa posicion.")
        elseif kappa > 1000
            println("\nAtencion: κ > 10^3. Sensibilidad alta.")
            println("   Los errores de medicion pueden afectar significativamente.")
        else
            println("\nBIEN CONDICIONADO (κ ≤ 1000).")
            println("   Los ajustes recomendados son numericamente estables.")
        end

        println("\nDescomposicion SVD de A:")
        println("   σ1 = $(round(S[1], digits=4)) (direccion mas sensible)")
        println("   σ2 = $(round(S[2], digits=4))")
        println("   σ3 = $(round(S[3], digits=4))")
        if length(S) >= 4
            println("   σ4 = $(round(S[4], digits=4)) (direccion menos sensible)")
        end

        if length(S) >= 4 && S[4]/S[1] < 0.1
            println("\nREDUNDANCIA DETECTADA (σ4/σ1 = $(round(S[4]/S[1], digits=3)))")
            println("   Combinacion de ajustes con poco efecto:")
            println("     ∆a_s ≈ $(round(V[1,4], digits=3)) · t")
            println("     ∆h_s ≈ $(round(V[2,4], digits=3)) · t")
            println("     ∆a_m ≈ $(round(V[3,4], digits=3)) · t")
            println("     ∆h_m ≈ $(round(V[4,4], digits=3)) · t")
        else
            println("\nSin redundancias significativas.")
        end

        println("\nRECOMENDACIONES DE AJUSTE:")
        problemas = false

        if ang_rodilla < 140
            println("   Angulo rodilla muy cerrado ($(round(ang_rodilla, digits=1))° < 140°).")
            println("   Sube el sillin (aumenta h_s) en 1-2 cm.")
            problemas = true
        elseif ang_rodilla > 155
            println("   Angulo rodilla muy abierto ($(round(ang_rodilla, digits=1))° > 155°).")
            println("   Baja el sillin (disminuye h_s) en 1-2 cm.")
            problemas = true
        else
            println("   Angulo de rodilla en rango ideal (140°-155°).")
        end

        if kops > 0.02
            println("   KOPS muy adelante ($(round(kops*100, digits=1)) cm > 2 cm).")
            println("   Atrasa el sillin (disminuye a_s) en 0.5-1 cm.")
            problemas = true
        elseif kops < -0.02
            println("   KOPS muy atras ($(round(kops*100, digits=1)) cm < -2 cm).")
            println("   Adelanta el sillin (aumenta a_s) en 0.5-1 cm.")
            problemas = true
        else
            println("   KOPS en rango ideal (±2 cm).")
        end

        if ang_tronco < 30
            println("   Torso muy inclinado ($(round(ang_tronco, digits=1))° < 30°).")
            println("   Sube el manillar (aumenta h_m) o acercalo (disminuye a_m).")
            problemas = true
        elseif ang_tronco > 60
            println("   Torso muy vertical ($(round(ang_tronco, digits=1))° > 60°).")
            println("   Baja el manillar (disminuye h_m) o alejalo (aumenta a_m).")
            problemas = true
        else
            println("   Angulo de tronco en rango ideal (30°-60°).")
        end

        if !problemas
            println("   Configuracion optima. Todos los valores estan en rangos ideales.")
        end
        println("\n" * "="^80)
    end

    return A, kappa, S, V
end

function plot_kappa_heatmap(a_m, h_m;
                            h_s_range=0.60:0.005:0.85,
                            a_s_range=0.00:0.005:0.12,
                            kwargs...)
    kappa_mat = zeros(length(h_s_range), length(a_s_range))
    for (i, h_s) in enumerate(h_s_range)
        for (j, a_s) in enumerate(a_s_range)
            try
                A = sensitivity_matrix(a_s, h_s, a_m, h_m; kwargs...)
                kappa_mat[i, j] = cond(A)
            catch
                kappa_mat[i, j] = NaN
            end
        end
    end

    p = heatmap(h_s_range, a_s_range, kappa_mat',
                xlabel="Altura sillin (h_s) [m]",
                ylabel="Avance sillin (a_s) [m]",
                title="Mapa de calor: κ(A)",
                color=:viridis, clims=(1, 10000), yflip=false)
    savefig(p, joinpath(@__DIR__, "../output/bike_kappa_heatmap_completo.png"))
    display(p)
    println("Mapa de calor guardado en: output/bike_kappa_heatmap_completo.png")
    return p
end

# ================================================================
# VISUALIZACION SIMPLE (la que funcionaba)
# ================================================================

function plot_bike_geometry(a_s, h_s, a_m, h_m; kwargs...)
    pos = calcular_posiciones(a_s, h_s, a_m, h_m; kwargs...)
    
    Hx, Hy = pos[:cadera]
    Kx, Ky = pos[:rodilla]
    Ax, Ay = pos[:tobillo]
    Sx, Sy = pos[:hombro]
    Mx, My = pos[:manillar]
    Px, Py = pos[:pedal]

    y_med = medidas_salida(a_s, h_s, a_m, h_m; kwargs...)
    ang_rodilla, kops, _ = y_med

    brazo_cm = round(get(kwargs, :brazo, 0.35)*100, digits=1)

    p = plot(aspect_ratio=:equal, 
             title="Geometria del Ciclista",
             xlabel="Distancia horizontal (m)",
             ylabel="Altura (m)",
             legend=:outerright,
             framestyle=:box,
             grid=true)

    # Cuerpo del ciclista
    plot!(p, [Hx, Sx], [Hy, Sy], color=:blue, linewidth=3, label="Torso")
    plot!(p, [Sx, Mx], [Sy, My], color=:orange, linewidth=3, label="Brazo ($brazo_cm cm)")
    plot!(p, [Hx, Kx], [Hy, Ky], color=:red, linewidth=3, label="Femur")
    plot!(p, [Kx, Ax], [Ky, Ay], color=:green, linewidth=3, label="Tibia")
    plot!(p, [Ax, Px], [Ay, Py], color=:brown, linewidth=3, label="Pie")

    # Articulaciones
    scatter!(p, [Px], [Py], color=:black, markershape=:circle, markersize=6, label="Pedalier")
    scatter!(p, [Hx], [Hy], color=:blue, markershape=:circle, markersize=6, label="Sillin")
    scatter!(p, [Mx], [My], color=:orange, markershape=:circle, markersize=6, label="Manillar")
    scatter!(p, [Kx], [Ky], color=:red, markershape=:diamond, markersize=8, label="Rodilla")
    scatter!(p, [Sx], [Sy], color=:purple, markershape=:circle, markersize=6, label="Hombro")
    scatter!(p, [Ax], [Ay], color=:green, markershape=:circle, markersize=6, label="Tobillo")

    # Anotaciones
    annotate!(p, Kx, Ky+0.05, text("Angulo Rodilla: $(round(ang_rodilla, digits=1))°", :red, 9))
    annotate!(p, Kx+0.05, Ky-0.05, text("KOPS: $(round(kops*100, digits=1)) cm", :blue, 9))

    display(p)
    savefig(p, joinpath(@__DIR__, "../output/bike_geometry.png"))
    println("Grafico guardado en: output/bike_geometry.png")
    
    return p
end

end  # module