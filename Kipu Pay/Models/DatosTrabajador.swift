//
//  DatosTrabajador.swift
//  Kipu Pay
//

import Foundation

enum SistemaPensiones: String, CaseIterable, Identifiable {
    case onp = "ONP"
    case afp = "AFP"

    var id: String { rawValue }
}

/// Datos del mes ya validados, listos para calcular la boleta.
struct DatosTrabajador: Equatable {
    var sueldoBasico: Decimal
    var diasLaborados: Int
    var tieneHijos: Bool
    var sistemaPensiones: SistemaPensiones
    /// Solo se usa cuando `sistemaPensiones == .afp`.
    var nombreAFP: String?
    var horasExtras25: Int = 0
    var horasExtras35: Int = 0
    var adelantos: Decimal = 0
}
