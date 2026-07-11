module Aplicacion

using LinearAlgebra
using ..Transformaciones

export aplicar_secuencia

function aplicar_secuencia(P, transforms)
    T_acum = Matrix{Float64}(I, 3, 3)
    historial = []
    for T in transforms
        T_acum = T * T_acum
        P_trans = T_acum * P
        A = T_acum[1:2, 1:2]
        # Usamos la norma de Frobenius, pero sin la constante (usamos el número 2 para norma espectral)
        err_ort = norm(A' * A - I)  # Por defecto es la norma 2 (espectral)
        # Si quieres Frobenius específicamente, usa: norm(A' * A - I, Frobenius) 
        # pero necesitas importar Frobenius: using LinearAlgebra: Frobenius
        kappa = cond(T_acum)
        push!(historial, (P_trans, err_ort, kappa))
    end
    return historial
end

end