module BikeFittingCompleto

using LinearAlgebra, Plots

export calcular_posiciones, medidas_salida, sensitivity_matrix,
       analyze_bike_fitting, plot_kappa_heatmap, plot_bike_geometry

# ================================================================
# GEOMETRIA COMPLETA (con corrección de rodilla y manejo de NaN)
# ================================================================

function calcular_posiciones(a_s, h_s, a_m, h_m;
                             femur=0.42, tibia=0.40, pie=0.10,
                             torso=0.50, brazo=0.35, biela=0.17)
    
    Hx, Hy = a_s, h_s           # Cadera (sillín)
    Mx, My = a_m, h_m           # Manillar
    Sx, Sy = Mx, My             # Hombro (asumimos alineado con manillar)
    Px, Py = 0.0, -biela        # Pedal

    # Distancia cadera-pedal
    d = sqrt((Px - Hx)^2 + (Py - Hy)^2)

    # Si d es inválida, ajustamos Hy para que sea válida
    if d > femur + tibia || d < abs(femur - tibia)
        # Intentamos mover la cadera verticalmente
        d_objetivo = femur + tibia - 0.01
        # Resolver: sqrt(Hx^2 + (Hy + biela)^2) = d_objetivo
        # => Hy = sqrt(d_objetivo^2 - Hx^2) - biela
        Hy_calc = sqrt(max(0.0, d_objetivo^2 - Hx^2)) - biela
        if Hy_calc > 0.0
            Hy = Hy_calc
            d = d_objetivo
        else
            # Fallback: colocar la rodilla en posición intermedia
            Kx = (Hx + Px) / 2 - 0.05
            Ky = (Hy + Py) / 2 + 0.05
            return Dict(
                :cadera => (Hx, Hy),
                :rodilla => (Kx, Ky),
                :tobillo => (0.0, -biela + pie),
                :hombro => (Sx, Sy),
                :manillar => (Mx, My),
                :pedal => (Px, Py)
            )
        end
    end

    # Cálculo de la intersección de dos círculos
    ex = (Px - Hx) / d
    ey = (Py - Hy) / d
    p = (femur^2 - tibia^2 + d^2) / (2d)
    q = sqrt(max(0.0, femur^2 - p^2))

    Kx1 = Hx + p*ex - q*ey
    Ky1 = Hy + p*ey + q*ex
    Kx2 = Hx + p*ex + q*ey
    Ky2 = Hy + p*ey - q*ex

    function ang_rod(Kx, Ky)
        v1 = (Hx - Kx, Hy - Ky)
        v2 = (Px - Kx, Py - Ky)
        n1 = norm(v1)
        n2 = norm(v2)
        if n1 == 0.0 || n2 == 0.0
            return 180.0
        end
        cos_ang = clamp(dot(v1, v2) / (n1 * n2), -1.0, 1.0)
        return rad2deg(acos(cos_ang))
    end

    ang1 = ang_rod(Kx1, Ky1)
    ang2 = ang_rod(Kx2, Ky2)

    # Elegir la solución que dé un ángulo más cercano a 145°
    if abs(ang1 - 145) < abs(ang2 - 145)
        Kx, Ky = Kx1, Ky1
    else
        Kx, Ky = Kx2, Ky2
    end

    # Si el ángulo seleccionado es < 100 o > 170, forzar la otra solución
    ang_final = ang_rod(Kx, Ky)
    if ang_final < 100 || ang_final > 170
        # Probar la otra
        Kx_alt, Ky_alt = (Kx == Kx1) ? (Kx2, Ky2) : (Kx1, Ky1)
        if 120 <= ang_rod(Kx_alt, Ky_alt) <= 160
            Kx, Ky = Kx_alt, Ky_alt
        end
    end

    # Tobillo
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

    # Ángulo de rodilla
    v1 = (Hx - Kx, Hy - Ky)
    v2 = (Px - Kx, Py - Ky)
    n1 = norm(v1)
    n2 = norm(v2)
    if n1 == 0.0 || n2 == 0.0
        ang_rodilla = 180.0
    else
        cos_ang = clamp(dot(v1, v2) / (n1 * n2), -1.0, 1.0)
        ang_rodilla = rad2deg(acos(cos_ang))
    end

    # KOPS: positiva si la rodilla está adelante del pedal
    kops = Kx - Px

    # Ángulo del tronco (respecto a la horizontal, valor positivo)
    v_tronco = (Sx - Hx, Sy - Hy)
    ang_tronco = rad2deg(atan(v_tronco[2], v_tronco[1]))
    if ang_tronco < 0
        ang_tronco = -ang_tronco
    end

    return [ang_rodilla, kops, ang_tronco]
end

function sensitivity_matrix(a_s, h_s, a_m, h_m; kwargs...)
    delta = 0.001
    A = zeros(3, 4)

    # Derivada respecto a a_s (avance sillín)
    y_plus = medidas_salida(a_s + delta, h_s, a_m, h_m; kwargs...)
    y_minus = medidas_salida(a_s - delta, h_s, a_m, h_m; kwargs...)
    A[:, 1] = (y_plus - y_minus) / (2delta)

    # Derivada respecto a h_s (altura sillín)
    y_plus = medidas_salida(a_s, h_s + delta, a_m, h_m; kwargs...)
    y_minus = medidas_salida(a_s, h_s - delta, a_m, h_m; kwargs...)
    A[:, 2] = (y_plus - y_minus) / (2delta)

    # Derivada respecto a a_m (alcance manillar)
    y_plus = medidas_salida(a_s, h_s, a_m + delta, h_m; kwargs...)
    y_minus = medidas_salida(a_s, h_s, a_m - delta, h_m; kwargs...)
    A[:, 3] = (y_plus - y_minus) / (2delta)

    # Derivada respecto a h_m (altura manillar)
    y_plus = medidas_salida(a_s, h_s, a_m, h_m + delta; kwargs...)
    y_minus = medidas_salida(a_s, h_s, a_m, h_m - delta; kwargs...)
    A[:, 4] = (y_plus - y_minus) / (2delta)

    # Reemplazar NaN o Inf por 0 para evitar errores en SVD
    A[isnan.(A)] .= 0.0
    A[isinf.(A)] .= 0.0

    return A
end

function analyze_bike_fitting(a_s, h_s, a_m, h_m; verbose=true, kwargs...)
    A = sensitivity_matrix(a_s, h_s, a_m, h_m; kwargs...)
    # Calcular condición con manejo de excepción
    kappa = try
        cond(A)
    catch
        println("   Advertencia: fallo en cond(A). Asignando κ = 1e10")
        1e10
    end
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
        println("   Brazo = $(round(get(kwargs, :brazo, 0.35)*100, digits=1)) cm")
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

        # Ajuste exacto del sillín
        angulo_ideal = 145.0
        if ang_rodilla < 140 || ang_rodilla > 155
            delta_h = 0.001
            y_plus = medidas_salida(a_s, h_s + delta_h, a_m, h_m; kwargs...)
            ang_plus = y_plus[1]
            derivada = (ang_plus - ang_rodilla) / delta_h
            if abs(derivada) > 1e-6
                ajuste_necesario = (angulo_ideal - ang_rodilla) / derivada
                println("\nAJUSTE EXACTO DEL SILLIN:")
                println("   Para alcanzar $(angulo_ideal)°: $(round(ajuste_necesario*100, digits=1)) cm $(ajuste_necesario > 0 ? "subir" : "bajar") el sillin.")
                println("   (Sensibilidad: $(round(derivada*100, digits=2))° por cm)")
            else
                println("\n   No se puede ajustar el ángulo con la altura del sillin (sensibilidad muy baja).")
            end
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
# VISUALIZACION MEJORADA
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

    x_vals = [Hx, Kx, Ax, Sx, Mx, Px]
    y_vals = [Hy, Ky, Ay, Sy, My, Py]
    x_min = minimum(x_vals) - 0.1
    x_max = maximum(x_vals) + 0.1
    y_min = minimum(y_vals) - 0.1
    y_max = maximum(y_vals) + 0.1

    p = plot(aspect_ratio=:equal, 
             title="Geometria del Ciclista",
             xlabel="Distancia horizontal (m)",
             ylabel="Altura (m)",
             legend=:outerright,
             framestyle=:box,
             grid=true,
             xlims=(x_min, x_max),
             ylims=(y_min, y_max))

    plot!(p, [Hx, Sx], [Hy, Sy], color=:blue, linewidth=3, label="Torso")
    plot!(p, [Sx, Mx], [Sy, My], color=:orange, linewidth=3, label="Brazo ($brazo_cm cm)")
    plot!(p, [Hx, Kx], [Hy, Ky], color=:red, linewidth=3, label="Femur")
    plot!(p, [Kx, Ax], [Ky, Ay], color=:green, linewidth=3, label="Tibia")
    plot!(p, [Ax, Px], [Ay, Py], color=:brown, linewidth=3, label="Pie")

    scatter!(p, [Px], [Py], color=:black, markershape=:circle, markersize=8, label="Pedalier")
    scatter!(p, [Hx], [Hy], color=:blue, markershape=:circle, markersize=8, label="Sillin")
    scatter!(p, [Mx], [My], color=:orange, markershape=:circle, markersize=8, label="Manillar")
    scatter!(p, [Kx], [Ky], color=:red, markershape=:diamond, markersize=10, label="Rodilla")
    scatter!(p, [Sx], [Sy], color=:purple, markershape=:circle, markersize=8, label="Hombro")
    scatter!(p, [Ax], [Ay], color=:green, markershape=:circle, markersize=8, label="Tobillo")

    annotate!(p, Kx, Ky+0.05, text("Angulo Rodilla: $(round(ang_rodilla, digits=1))°", :red, 10))
    annotate!(p, Kx+0.05, Ky-0.05, text("KOPS: $(round(kops*100, digits=1)) cm", :blue, 10))

    display(p)
    savefig(p, joinpath(@__DIR__, "../output/bike_geometry.png"))
    println("Grafico guardado en: output/bike_geometry.png")
    
    return p
end

end  # module