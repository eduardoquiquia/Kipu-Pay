//
//  ParametrosLaborales.swift
//  Kipu Pay
//
//  Parámetros laborales centralizados. Ninguna fórmula escribe estos valores
//  directamente: todas los leen de aquí (equivale a la hoja "Parámetros" del Excel).
//
//  Fuentes según Actividad_Grupo_B.docx (consultado el 28/10/2026).
//  Verificar en la fuente oficial antes de usarlos en una boleta real.
//

import Foundation

/// Tasas de descuento de una AFP, expresadas como fracción (0.10 = 10%).
struct TasasAFP: Equatable {
    let fondo: Decimal
    let comision: Decimal
    let seguro: Decimal
    /// Aclaración que se muestra bajo el selector de AFP.
    var nota: String = ""
}

enum ParametrosLaborales {

    /// Remuneración Mínima Vital. Fuente: D.S. de la RMV, vigente desde el 01/10/2026.
    static let rmv = decimal("1230.00")

    /// Asignación familiar: 10% de la RMV. Fuente: Ley 25129.
    static let porcentajeAsignacionFamiliar = decimal("0.10")

    /// Aporte al Sistema Nacional de Pensiones. Fuente: D.L. 19990.
    static let tasaONP = decimal("0.13")

    /// Aporte del empleador a EsSalud. Fuente: Ley 26790.
    static let tasaEsSalud = decimal("0.09")

    /// Multiplicadores de sobretiempo (25% y 35%). Fuente: normas de jornada y sobretiempo.
    static let multiplicadorHorasExtras25 = decimal("1.25")
    static let multiplicadorHorasExtras35 = decimal("1.35")

    /// Divisores para pasar de sueldo mensual a diario y a hora.
    static let diasDelMes = 30
    static let horasPorJornada = 8

    /// Remuneración máxima asegurable: la prima de seguro AFP solo se calcula hasta este tope.
    /// Fuente: SBS, comisiones y primas del SPP, devengue octubre 2026 (vigente oct–dic 2026).
    static let remuneracionMaximaAsegurable = decimal("12732.70")

    /// AFP de prueba del laboratorio. Se conserva solo para los casos 3 y 4 del enunciado.
    static let afpEjemplo = "AFP Ejemplo"
    /// AFP que aparece seleccionada por defecto.
    static let afpPorDefecto = "AFP Habitat · Flujo"

    /// Diccionario de tasas por AFP.
    /// Fuente: SBS, comisiones y primas de seguros del SPP, devengue octubre 2026.
    /// - Aporte al fondo: 10% en todas las AFP.
    /// - Prima de seguro: 1.37% en todas las AFP (Ley 32123), con tope en la remuneración máxima asegurable.
    /// - Comisión "Flujo": porcentaje mensual sobre la remuneración.
    /// - Comisión "Mixta": 0% sobre la remuneración; la AFP cobra un % anual sobre el saldo del fondo,
    ///   que no aparece en la boleta.
    static let tasasAFP: [String: TasasAFP] = {
        let fondo = decimal("0.10")
        let seguro = decimal("0.0137")
        let comisionesFlujo: [(nombre: String, flujo: String, saldoAnual: String)] = [
            ("AFP Habitat", "0.0147", "1.25%"),
            ("AFP Integra", "0.0155", "0.78%"),
            ("AFP Prima", "0.0160", "1.25%"),
            ("AFP Profuturo", "0.0169", "0.68%")
        ]
        var tasas: [String: TasasAFP] = [:]
        for afp in comisionesFlujo {
            tasas["\(afp.nombre) · Flujo"] = TasasAFP(
                fondo: fondo, comision: decimal(afp.flujo), seguro: seguro,
                nota: "Comisión por flujo: se descuenta cada mes sobre la remuneración.")
            tasas["\(afp.nombre) · Mixta"] = TasasAFP(
                fondo: fondo, comision: 0, seguro: seguro,
                nota: "Comisión mixta: 0% sobre la remuneración; la AFP cobra \(afp.saldoAnual) anual sobre el saldo del fondo (no figura en la boleta).")
        }
        tasas[afpEjemplo] = TasasAFP(
            fondo: fondo, comision: decimal("0.016"), seguro: decimal("0.0135"),
            nota: "Valores de prueba del laboratorio (casos 3 y 4), no son tasas reales.")
        return tasas
    }()

    /// AFP disponibles en el selector: primero las reales, al final la de prueba.
    static var afpsDisponibles: [String] {
        tasasAFP.keys.filter { $0 != afpEjemplo }.sorted() + [afpEjemplo]
    }

    // MARK: - Límites de validación (protección ante valores no representables)

    static let diasMinimos = 1
    static let diasMaximos = 30
    static let montoMaximo = decimal("10000000.00")
    static let horasExtrasMaximas = 720

    /// Convierte un literal a `Decimal` sin pasar por `Double`.
    private static func decimal(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
