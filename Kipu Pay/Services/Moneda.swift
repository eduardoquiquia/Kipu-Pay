//
//  Moneda.swift
//  Kipu Pay
//

import Foundation

extension Decimal {
    /// Redondeo monetario a 2 decimales, mitad hacia arriba (igual que REDONDEAR en Excel).
    func redondeadoMoneda() -> Decimal {
        var valor = self
        var resultado = Decimal()
        NSDecimalRound(&resultado, &valor, 2, .plain)
        return resultado
    }

    /// Importe en soles con formato es_PE, p. ej. "S/ 2,175.00". Solo para mostrar.
    var formatoSoles: String {
        formatted(.currency(code: "PEN")
            .locale(Locale(identifier: "es_PE"))
            .precision(.fractionLength(2)))
    }

    /// Tasa como porcentaje con 2 decimales, p. ej. 0.016 → "1.60%".
    var formatoPorcentaje: String {
        (self * 100).formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "es_PE"))) + "%"
    }
}
