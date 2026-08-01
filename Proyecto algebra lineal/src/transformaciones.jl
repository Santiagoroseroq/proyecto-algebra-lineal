    module Transformaciones

    export rotacion, traslacion, escalado

    function rotacion(theta)
        c = cos(theta)
        s = sin(theta)
        return [c -s 0; s c 0; 0 0 1]
    end

    function traslacion(tx, ty)
        return [1 0 tx; 0 1 ty; 0 0 1]
    end

    function escalado(sx, sy)
        return [sx 0 0; 0 sy 0; 0 0 1]
    end

    end