module Aplicacion

using LinearAlgebra
using ..Transformaciones
using Base: invokelatest

export aplicar_secuencia

function aplicar_secuencia(P, transforms)
    T_acum = Matrix{Float64}(I, 3, 3)
    historial = []
    for T in transforms
        T_acum = T * T_acum
        P_trans = T_acum * P
        A = T_acum[1:2, 1:2]
        # Usamos norm por defecto (Frobenius) sin importar Frobenius explícitamente
        err_ort = norm(A' * A - I)  # norm por defecto es Frobenius para matrices
        kappa = cond(T_acum)
        push!(historial, (P_trans, err_ort, kappa, T_acum, A))
    end
    return historial
end

end