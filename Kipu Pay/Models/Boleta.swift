//
//  Boleta.swift
//  Kipu Pay
//
//  Cálculo de la boleta de pago. Cada concepto se redondea a 2 decimales
//  antes de sumarlo, como exige el enunciado.
//

import Foundation

enum TipoConcepto {
    case remuneracion
    case descuento
    case aportacionEmpleador
}

/// Una línea de la boleta (p. ej. "AFP comisión 1.60% → S/ 52.05").
struct ConceptoBoleta: Identifiable, Equatable {
    let id: String
    let nombre: String
    /// Cómo se obtuvo el importe, p. ej. "13% del total". Vacío si no aplica.
    let detalle: String
    let monto: Decimal
    let tipo: TipoConcepto
    /// `false` para conceptos que no corresponden (se muestran en S/ 0.00).
    let aplica: Bool
}

enum ErrorBoleta: LocalizedError, Equatable {
    case datosInvalidos(String)
    case tasasAFPNoConfiguradas(String)
    case resultadoNoRepresentable

    var errorDescription: String? {
        switch self {
        case .datosInvalidos(let motivo):
            return motivo
        case .tasasAFPNoConfiguradas(let nombre):
            return "No hay tasas configuradas para \"\(nombre)\". Agrega sus tasas verificadas (SBS) antes de calcular."
        case .resultadoNoRepresentable:
            return "Los importes son demasiado grandes para calcular una boleta confiable."
        }
    }
}

final class Boleta {

    let datos: DatosTrabajador

    // Bloque A: Remuneraciones
    let sueldoComputable: Decimal
    let asignacionFamiliar: Decimal
    let valorHora: Decimal
    let horasExtras25: Decimal
    let horasExtras35: Decimal

    // Bloque B: Retenciones y descuentos
    let onp: Decimal
    let afpFondo: Decimal
    let afpComision: Decimal
    let afpSeguro: Decimal
    let adelantos: Decimal

    // Bloque C: Aportaciones del empleador
    let essalud: Decimal

    /// Todos los conceptos de la boleta, en el orden en que se muestran.
    /// Los totales se obtienen sumando este array.
    let conceptos: [ConceptoBoleta]

    let totalRemuneraciones: Decimal
    let totalDescuentos: Decimal
    let netoAPagar: Decimal

    init(datos: DatosTrabajador, tasasAFP: [String: TasasAFP] = ParametrosLaborales.tasasAFP) throws {
        try Boleta.validar(datos)
        self.datos = datos

        let p = ParametrosLaborales.self
        let dias = Decimal(p.diasDelMes)
        let horas = Decimal(p.horasPorJornada)

        // Remuneraciones. Se multiplica antes de dividir (misma fórmula): así el resultado es
        // exacto y no se arrastran periódicos truncados (2500.55 ÷ 30 × 15 daría 1250.2749… → 1250.27).
        sueldoComputable = (datos.sueldoBasico * Decimal(datos.diasLaborados) / dias).redondeadoMoneda()
        asignacionFamiliar = datos.tieneHijos
            ? (p.rmv * p.porcentajeAsignacionFamiliar).redondeadoMoneda()
            : 0
        valorHora = (datos.sueldoBasico / (dias * horas)).redondeadoMoneda()
        horasExtras25 = (valorHora * p.multiplicadorHorasExtras25 * Decimal(datos.horasExtras25)).redondeadoMoneda()
        horasExtras35 = (valorHora * p.multiplicadorHorasExtras35 * Decimal(datos.horasExtras35)).redondeadoMoneda()

        let remuneraciones = [
            ConceptoBoleta(id: "sueldo", nombre: "Sueldo computable",
                           detalle: "Básico ÷ 30 × \(datos.diasLaborados) días",
                           monto: sueldoComputable, tipo: .remuneracion, aplica: true),
            ConceptoBoleta(id: "asignacion", nombre: "Asignación familiar",
                           detalle: datos.tieneHijos ? "10% de la RMV" : "Sin hijos",
                           monto: asignacionFamiliar, tipo: .remuneracion, aplica: datos.tieneHijos),
            ConceptoBoleta(id: "he25", nombre: "Horas extras 25%",
                           detalle: "\(datos.horasExtras25) h × \(valorHora.formatoSoles) × 1.25",
                           monto: horasExtras25, tipo: .remuneracion, aplica: datos.horasExtras25 > 0),
            ConceptoBoleta(id: "he35", nombre: "Horas extras 35%",
                           detalle: "\(datos.horasExtras35) h × \(valorHora.formatoSoles) × 1.35",
                           monto: horasExtras35, tipo: .remuneracion, aplica: datos.horasExtras35 > 0)
        ]
        let total = Boleta.suma(remuneraciones)

        // Pensión: ONP o AFP, nunca ambas
        let esAFP = datos.sistemaPensiones == .afp
        var tasas: TasasAFP?
        if esAFP {
            let nombre = datos.nombreAFP ?? ""
            guard let encontradas = tasasAFP[nombre] else {
                throw ErrorBoleta.tasasAFPNoConfiguradas(nombre.isEmpty ? "AFP sin seleccionar" : nombre)
            }
            tasas = encontradas
        }
        onp = esAFP ? 0 : (total * p.tasaONP).redondeadoMoneda()
        afpFondo = tasas.map { (total * $0.fondo).redondeadoMoneda() } ?? 0
        afpComision = tasas.map { (total * $0.comision).redondeadoMoneda() } ?? 0
        afpSeguro = tasas.map { (total * $0.seguro).redondeadoMoneda() } ?? 0
        adelantos = datos.adelantos.redondeadoMoneda()

        let descuentos = [
            ConceptoBoleta(id: "onp", nombre: "ONP", detalle: esAFP ? "No aplica" : "13% del total",
                           monto: onp, tipo: .descuento, aplica: !esAFP),
            ConceptoBoleta(id: "afpFondo", nombre: "AFP fondo",
                           detalle: tasas.map { $0.fondo.formatoPorcentaje } ?? "No aplica",
                           monto: afpFondo, tipo: .descuento, aplica: esAFP),
            ConceptoBoleta(id: "afpComision", nombre: "AFP comisión",
                           detalle: tasas.map { $0.comision.formatoPorcentaje } ?? "No aplica",
                           monto: afpComision, tipo: .descuento, aplica: esAFP),
            ConceptoBoleta(id: "afpSeguro", nombre: "AFP seguro",
                           detalle: tasas.map { $0.seguro.formatoPorcentaje } ?? "No aplica",
                           monto: afpSeguro, tipo: .descuento, aplica: esAFP),
            ConceptoBoleta(id: "adelantos", nombre: "Adelantos", detalle: "Monto ingresado",
                           monto: adelantos, tipo: .descuento, aplica: adelantos > 0)
        ]

        // EsSalud lo paga el empleador: no entra en los descuentos.
        essalud = (total * p.tasaEsSalud).redondeadoMoneda()
        let aportaciones = [
            ConceptoBoleta(id: "essalud", nombre: "EsSalud (9%)", detalle: "Lo paga el empleador",
                           monto: essalud, tipo: .aportacionEmpleador, aplica: true)
        ]

        conceptos = remuneraciones + descuentos + aportaciones
        totalRemuneraciones = total
        totalDescuentos = Boleta.suma(descuentos)
        netoAPagar = totalRemuneraciones - totalDescuentos

        guard [totalRemuneraciones, totalDescuentos, netoAPagar, essalud].allSatisfy({ $0.isFinite && !$0.isNaN }) else {
            throw ErrorBoleta.resultadoNoRepresentable
        }
    }

    func conceptos(de tipo: TipoConcepto) -> [ConceptoBoleta] {
        conceptos.filter { $0.tipo == tipo }
    }

    /// El ejercicio resta los adelantos tal cual; un neto negativo se muestra pero requiere revisión.
    var netoEsNegativo: Bool { netoAPagar < 0 }

    // MARK: - Auxiliares

    private static func suma(_ conceptos: [ConceptoBoleta]) -> Decimal {
        conceptos.reduce(Decimal(0)) { $0 + $1.monto }
    }

    /// Segunda línea de defensa: la interfaz ya valida, pero la clase no confía en ello.
    private static func validar(_ datos: DatosTrabajador) throws {
        let p = ParametrosLaborales.self
        guard datos.sueldoBasico > 0, datos.sueldoBasico <= p.montoMaximo else {
            throw ErrorBoleta.datosInvalidos("El sueldo básico debe ser mayor que cero y menor o igual a \(p.montoMaximo.formatoSoles).")
        }
        guard (p.diasMinimos...p.diasMaximos).contains(datos.diasLaborados) else {
            throw ErrorBoleta.datosInvalidos("Los días laborados deben estar entre \(p.diasMinimos) y \(p.diasMaximos).")
        }
        guard (0...p.horasExtrasMaximas).contains(datos.horasExtras25),
              (0...p.horasExtrasMaximas).contains(datos.horasExtras35) else {
            throw ErrorBoleta.datosInvalidos("Las horas extras deben estar entre 0 y \(p.horasExtrasMaximas).")
        }
        guard datos.adelantos >= 0, datos.adelantos <= p.montoMaximo else {
            throw ErrorBoleta.datosInvalidos("Los adelantos deben ser cero o positivos.")
        }
    }
}
