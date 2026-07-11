# ============================================================
# main_bike_completo.jl - Análisis INTERACTIVO de Bike Fitting
# ============================================================

using LinearAlgebra, Plots

include("bikefitting_completo.jl")
using .BikeFittingCompleto

function preguntar_medida(descripcion, nombre, unidad, valor_por_defecto)
    println(descripcion)
    print("   Ingrese $nombre ($unidad) [$valor_por_defecto]: ")
    entrada = readline()
    if entrada == ""
        println("   -> Usando valor por defecto: $valor_por_defecto $unidad")
        return valor_por_defecto
    else
        try
            valor = parse(Float64, entrada)
            println("   -> Registrado: $valor $unidad")
            return valor
        catch
            println("   Valor no valido. Usando $valor_por_defecto $unidad")
            return valor_por_defecto
        end
    end
end

output_dir = joinpath(@__DIR__, "../output")
if !isdir(output_dir)
    mkdir(output_dir)
    println("Carpeta output creada.")
end

println("\n" * "="^60)
println("MEDIDAS ANTROPOMETRICAS (del ciclista)")
println("="^60)
println("Estas medidas definen la geometria del cuerpo del ciclista.")
println()

femur = preguntar_medida(
    "Femur: distancia desde la articulacion de la cadera hasta la rodilla.",
    "femur", "cm", 42.0
) / 100

tibia = preguntar_medida(
    "Tibia: distancia desde la rodilla hasta el tobillo.",
    "tibia", "cm", 40.0
) / 100

torso = preguntar_medida(
    "Torso: distancia desde la cadera hasta el hombro (punto oseo).",
    "torso", "cm", 50.0
) / 100

brazo = preguntar_medida(
    "Brazo: distancia desde el hombro (hueso prominente) hasta la muñeca (pliegue).",
    "brazo", "cm", 35.0
) / 100

pie = preguntar_medida(
    "Pie: distancia desde el tobillo hasta la punta del pie (medida horizontal).",
    "pie", "cm", 10.0
) / 100

biela = preguntar_medida(
    "Biela: longitud de la biela (distancia del centro del pedalier al centro del pedal).",
    "biela", "cm", 17.0
) / 100

medidas = Dict(
    :femur => femur,
    :tibia => tibia,
    :pie   => pie,
    :torso => torso,
    :brazo => brazo,
    :biela => biela
)

println("\nMedidas antropometricas registradas:")
for (k, v) in medidas
    println("   $k = $(round(v*100, digits=1)) cm")
end

println("\n" * "="^60)
println("CONFIGURACION ACTUAL DE LA BICICLETA")
println("="^60)
println("Todas las medidas se toman desde el centro del pedalier.")
println()

h_s = preguntar_medida(
    "Altura del sillin: distancia vertical desde el centro del pedalier hasta el sillin.",
    "altura del sillin", "cm", 75.0
) / 100

a_s = preguntar_medida(
    "Avance del sillin: distancia horizontal desde el centro del pedalier hasta la punta del sillin.",
    "avance del sillin", "cm", 5.0
) / 100

h_m = preguntar_medida(
    "Altura del manillar: distancia vertical desde el centro del pedalier hasta el manillar.",
    "altura del manillar", "cm", 60.0
) / 100

a_m = preguntar_medida(
    "Alcance del manillar: distancia horizontal desde el centro del pedalier hasta el manillar.",
    "alcance del manillar", "cm", 10.0
) / 100

println("\nConfiguracion de la bicicleta registrada:")
println("   Altura sillin (h_s) = $(round(h_s*100, digits=1)) cm")
println("   Avance sillin (a_s) = $(round(a_s*100, digits=1)) cm")
println("   Altura manillar (h_m) = $(round(h_m*100, digits=1)) cm")
println("   Alcance manillar (a_m) = $(round(a_m*100, digits=1)) cm")

println("\n" * "="^60)
println("ANALISIS DE LA CONFIGURACION INGRESADA")
println("="^60)

BikeFittingCompleto.analyze_bike_fitting(a_s, h_s, a_m, h_m; verbose=true, medidas...)

println("\n" * "="^60)
println("VISUALIZANDO LA GEOMETRIA")
println("="^60)

BikeFittingCompleto.plot_bike_geometry(a_s, h_s, a_m, h_m; medidas...)

print("\nDesea probar otras configuraciones sugeridas? (s/n) [n]: ")
respuesta = lowercase(strip(readline()))
if respuesta in ["s", "si", "sí"]
    configs = [
        (h_s + 0.02, a_s - 0.01, h_m + 0.02, a_m - 0.02, "Sillin subido 2 cm, atrasado 1 cm; manillar subido 2 cm, acercado 2 cm"),
        (h_s - 0.02, a_s + 0.01, h_m - 0.02, a_m + 0.02, "Sillin bajado 2 cm, adelantado 1 cm; manillar bajado 2 cm, alejado 2 cm"),
        (h_s + 0.05, a_s - 0.02, h_m + 0.05, a_m - 0.03, "Ajuste radical: sillin alto y atras, manillar alto y cerca")
    ]
    for (h_s2, a_s2, h_m2, a_m2, desc) in configs
        println("\n" * "="^60)
        println("Probando: $desc")
        println("="^60)
        BikeFittingCompleto.analyze_bike_fitting(a_s2, h_s2, a_m2, h_m2; verbose=true, medidas...)
        BikeFittingCompleto.plot_bike_geometry(a_s2, h_s2, a_m2, h_m2; medidas...)
    end
end

println("\n" * "="^60)
println("GENERANDO MAPA DE CALOR DE κ(A)")
println("="^60)

BikeFittingCompleto.plot_kappa_heatmap(a_m, h_m; h_s_range=0.60:0.005:0.85,
                   a_s_range=0.00:0.005:0.12, medidas...)

println("\n" * "="^60)
println("BUSCANDO ZONAS CRITICAS (κ > 10^4)")
println("="^60)

h_s_range = 0.60:0.01:0.85
a_s_range = 0.00:0.01:0.12
zonas_criticas = []
for h_s2 in h_s_range
    for a_s2 in a_s_range
        try
            A = BikeFittingCompleto.sensitivity_matrix(a_s2, h_s2, a_m, h_m; medidas...)
            if cond(A) > 1e4
                push!(zonas_criticas, (round(h_s2, digits=3), round(a_s2, digits=3)))
            end
        catch
        end
    end
end

if isempty(zonas_criticas)
    println("No se encontraron zonas con κ > 10^4 en el rango analizado.")
else
    println("ZONAS CRITICAS (κ > 10^4):")
    for (h, a) in zonas_criticas[1:min(10, length(zonas_criticas))]
        println("   h_s = $h m, a_s = $a m")
    end
    if length(zonas_criticas) > 10
        println("   ... y $(length(zonas_criticas)-10) mas.")
    end
end

println("\n" * "="^60)
println("ANALISIS COMPLETO")
println("="^60)
println("Revise la carpeta 'output/' para ver los graficos generados.")
