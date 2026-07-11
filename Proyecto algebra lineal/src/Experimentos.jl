module Experimentos

using ..Transformaciones
using ..Aplicacion

export secuencia_rotaciones_puras, secuencia_rotaciones_escalados
    export ejecutar_experimento1, ejecutar_experimento2

function secuencia_rotaciones_puras(n, angulo_grados)
    angulo_rad = deg2rad(angulo_grados)
    return [rotacion(angulo_rad) for _ in 1:n]
end

function secuencia_rotaciones_escalados(n, angulo_grados, sx, sy)
    angulo_rad = deg2rad(angulo_grados)
    seq = []
    for _ in 1:n
        push!(seq, rotacion(angulo_rad))
        push!(seq, escalado(sx, sy))
    end
    return seq
end

function ejecutar_experimento1(P; n=50, angulo=1.0)
    seq = secuencia_rotaciones_puras(n, angulo)
    return aplicar_secuencia(P, seq)
end

function ejecutar_experimento2(P; n=30, angulo=1.0, sx=1.05, sy=0.95)
    seq = secuencia_rotaciones_escalados(n, angulo, sx, sy)
    return aplicar_secuencia(P, seq)
end

end