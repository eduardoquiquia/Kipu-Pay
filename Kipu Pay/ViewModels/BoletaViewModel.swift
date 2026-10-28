//
//  BoletaViewModel.swift
//  Kipu Pay
//
//  Estado del formulario, validaciones y coordinación del cálculo.
//  No contiene fórmulas: el cálculo vive en `Boleta`.
//

import Foundation
import Observation

enum Campo: Hashable, CaseIterable {
    case sueldo, dias, afp, horas25, horas35, adelantos

    var etiqueta: String {
        switch self {
        case .sueldo: "Sueldo básico"
        case .dias: "Días laborados"
        case .afp: "AFP"
        case .horas25: "Horas extras al 25%"
        case .horas35: "Horas extras al 35%"
        case .adelantos: "Adelantos"
        }
    }
}

/// Texto tal como lo escribe el usuario.
struct EntradaFormulario: Equatable {
    var sueldo = ""
    var dias = ""
    var tieneHijos = false
    var sistemaPensiones: SistemaPensiones = .onp
    var afp = ParametrosLaborales.afpPorDefecto
    var horas25 = "0"
    var horas35 = "0"
    var adelantos = "0"
}

struct Validacion {
    let datos: DatosTrabajador?
    let errores: [Campo: String]
}

@Observable
final class BoletaViewModel {

    var entrada = EntradaFormulario()

    /// Última boleta calculada. Se reemplaza completa al recalcular.
    private(set) var boleta: Boleta?
    /// Error del cálculo que no corresponde a un campo concreto.
    private(set) var errorCalculo: String?
    /// Los errores por campo se muestran a partir del primer intento de cálculo.
    private(set) var mostrarErrores = false
    private(set) var boletaRevisada = false
    /// Cambian en cada intento; sirven como disparadores de animación y vibración.
    private(set) var calculosExitosos = 0
    private(set) var intentosFallidos = 0

    let afpsDisponibles: [String]
    private let tasasAFP: [String: TasasAFP]

    init(tasasAFP: [String: TasasAFP] = ParametrosLaborales.tasasAFP) {
        self.tasasAFP = tasasAFP
        // Primero las AFP reales en orden alfabético; la de prueba del laboratorio al final.
        let ejemplo = ParametrosLaborales.afpEjemplo
        self.afpsDisponibles = tasasAFP.keys.filter { $0 != ejemplo }.sorted()
            + (tasasAFP[ejemplo] == nil ? [] : [ejemplo])
    }

    var tasasAFPSeleccionada: TasasAFP? { tasasAFP[entrada.afp] }

    // MARK: - Validación

    var validacion: Validacion {
        let p = ParametrosLaborales.self
        var errores: [Campo: String] = [:]

        func leer<T>(_ resultado: Result<T, ErrorCampo>, _ campo: Campo) -> T? {
            switch resultado {
            case .success(let valor): return valor
            case .failure(let error): errores[campo] = error.mensaje; return nil
            }
        }

        let sueldo = leer(ValidadorEntrada.monto(entrada.sueldo, obligatorio: true, permiteCero: false), .sueldo)
        let dias = leer(ValidadorEntrada.entero(entrada.dias, obligatorio: true, rango: p.diasMinimos...p.diasMaximos), .dias)
        let horas25 = leer(ValidadorEntrada.entero(entrada.horas25, obligatorio: false, rango: 0...p.horasExtrasMaximas), .horas25)
        let horas35 = leer(ValidadorEntrada.entero(entrada.horas35, obligatorio: false, rango: 0...p.horasExtrasMaximas), .horas35)
        let adelantos = leer(ValidadorEntrada.monto(entrada.adelantos, obligatorio: false), .adelantos)

        let esAFP = entrada.sistemaPensiones == .afp
        if esAFP && tasasAFPSeleccionada == nil {
            errores[.afp] = "\(entrada.afp) no tiene tasas configuradas. No se puede calcular sin ellas."
        }

        guard errores.isEmpty, let sueldo, let dias, let horas25, let horas35, let adelantos else {
            return Validacion(datos: nil, errores: errores)
        }
        let datos = DatosTrabajador(
            sueldoBasico: sueldo,
            diasLaborados: dias,
            tieneHijos: entrada.tieneHijos,
            sistemaPensiones: entrada.sistemaPensiones,
            nombreAFP: esAFP ? entrada.afp : nil,
            horasExtras25: horas25,
            horasExtras35: horas35,
            adelantos: adelantos
        )
        return Validacion(datos: datos, errores: [:])
    }

    /// Error visible para un campo (solo después de pulsar Calcular).
    func error(para campo: Campo) -> String? {
        mostrarErrores ? validacion.errores[campo] : nil
    }

    /// Errores visibles, en el orden del formulario.
    var erroresVisibles: [(campo: Campo, mensaje: String)] {
        guard mostrarErrores else { return [] }
        let errores = validacion.errores
        return Campo.allCases.compactMap { campo in errores[campo].map { (campo, $0) } }
    }

    // MARK: - Estado de la boleta

    /// La boleta mostrada ya no corresponde a los datos actuales del formulario.
    var boletaDesactualizada: Bool {
        guard let boleta else { return false }
        return validacion.datos != boleta.datos
    }

    var etapaDatosCompleta: Bool { validacion.datos != nil }
    var etapaCalculoCompleta: Bool { boleta != nil && !boletaDesactualizada }
    var etapaRevisionCompleta: Bool { etapaCalculoCompleta && boletaRevisada }

    // MARK: - Acciones

    /// Devuelve `true` si se generó una boleta nueva.
    @discardableResult
    func calcular() -> Bool {
        mostrarErrores = true
        errorCalculo = nil
        guard let datos = validacion.datos else {
            intentosFallidos += 1
            return false
        }
        do {
            boleta = try Boleta(datos: datos, tasasAFP: tasasAFP)
            boletaRevisada = false
            calculosExitosos += 1
            return true
        } catch {
            boleta = nil
            errorCalculo = error.localizedDescription
            intentosFallidos += 1
            return false
        }
    }

    func marcarRevisada() {
        guard etapaCalculoCompleta else { return }
        boletaRevisada = true
    }
}
