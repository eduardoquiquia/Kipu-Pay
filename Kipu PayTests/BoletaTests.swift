//
//  BoletaTests.swift
//  Kipu PayTests
//
//  Casos oficiales del laboratorio y casos límite del cálculo.
//

import Foundation
import Testing
@testable import Kipu_Pay

private func d(_ texto: String) -> Decimal {
    Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
}

private func datos(sueldo: String, dias: Int, hijos: Bool, sistema: SistemaPensiones,
                   h25: Int = 0, h35: Int = 0, adelanto: String = "0") -> DatosTrabajador {
    DatosTrabajador(sueldoBasico: d(sueldo), diasLaborados: dias, tieneHijos: hijos,
                    sistemaPensiones: sistema,
                    nombreAFP: sistema == .afp ? ParametrosLaborales.afpEjemplo : nil,
                    horasExtras25: h25, horasExtras35: h35, adelantos: d(adelanto))
}

@MainActor
@Suite("Casos oficiales")
struct CasosOficialesTests {

    @Test("Caso 1: sin hijos, ONP, mes completo")
    func caso1() throws {
        let b = try Boleta(datos: datos(sueldo: "2500", dias: 30, hijos: false, sistema: .onp))
        #expect(b.sueldoComputable == d("2500.00"))
        #expect(b.asignacionFamiliar == 0)
        #expect(b.totalRemuneraciones == d("2500.00"))
        #expect(b.onp == d("325.00"))
        #expect(b.afpFondo == 0 && b.afpComision == 0 && b.afpSeguro == 0)
        #expect(b.totalDescuentos == d("325.00"))
        #expect(b.netoAPagar == d("2175.00"))
        #expect(b.essalud == d("225.00"))
    }

    @Test("Caso 2: con hijos y días incompletos")
    func caso2() throws {
        let b = try Boleta(datos: datos(sueldo: "1800", dias: 27, hijos: true, sistema: .onp))
        #expect(b.sueldoComputable == d("1620.00"))
        #expect(b.asignacionFamiliar == d("123.00"))
        #expect(b.totalRemuneraciones == d("1743.00"))
        #expect(b.onp == d("226.59"))
        #expect(b.netoAPagar == d("1516.41"))
        #expect(b.essalud == d("156.87"))
    }

    @Test("Caso 3: AFP, horas extras y adelanto")
    func caso3() throws {
        let b = try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: true, sistema: .afp,
                                        h25: 4, h35: 4, adelanto: "200"))
        #expect(b.sueldoComputable == d("3000.00"))
        #expect(b.asignacionFamiliar == d("123.00"))
        #expect(b.valorHora == d("12.50"))
        #expect(b.horasExtras25 == d("62.50"))
        #expect(b.horasExtras35 == d("67.50"))
        #expect(b.totalRemuneraciones == d("3253.00"))
        #expect(b.onp == 0)
        #expect(b.afpFondo == d("325.30"))
        #expect(b.afpComision == d("52.05"))   // 52.048
        #expect(b.afpSeguro == d("43.92"))     // 43.9155
        #expect(b.adelantos == d("200.00"))
        #expect(b.totalDescuentos == d("621.27"))
        #expect(b.netoAPagar == d("2631.73"))
        #expect(b.essalud == d("292.77"))
    }

    /// Valores de referencia obtenidos con un cálculo independiente (Python `decimal`,
    /// ROUND_HALF_UP, mismas reglas). El documento no publica la respuesta.
    @Test("Caso 4: evaluación del docente")
    func caso4() throws {
        let b = try Boleta(datos: datos(sueldo: "4200", dias: 24, hijos: true, sistema: .afp,
                                        h25: 2, h35: 2, adelanto: "100"))
        #expect(b.sueldoComputable == d("3360.00"))
        #expect(b.asignacionFamiliar == d("123.00"))
        #expect(b.valorHora == d("17.50"))
        #expect(b.horasExtras25 == d("43.75"))
        #expect(b.horasExtras35 == d("47.25"))
        #expect(b.totalRemuneraciones == d("3574.00"))
        #expect(b.afpFondo == d("357.40"))
        #expect(b.afpComision == d("57.18"))   // 57.184
        #expect(b.afpSeguro == d("48.25"))     // 48.249
        #expect(b.totalDescuentos == d("562.83"))
        #expect(b.netoAPagar == d("3011.17"))
        #expect(b.essalud == d("321.66"))
    }
}

@MainActor
@Suite("Reglas de cálculo")
struct ReglasCalculoTests {

    @Test("EsSalud no se descuenta del neto")
    func essaludNoSeDescuenta() throws {
        let b = try Boleta(datos: datos(sueldo: "2500", dias: 30, hijos: false, sistema: .onp))
        #expect(b.netoAPagar == b.totalRemuneraciones - b.totalDescuentos)
        #expect(!b.conceptos(de: .descuento).contains { $0.id == "essalud" })
    }

    @Test("Los totales salen del array de conceptos")
    func totalesDesdeConceptos() throws {
        let b = try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: true, sistema: .afp,
                                        h25: 4, h35: 4, adelanto: "200"))
        let rem = b.conceptos(de: .remuneracion).reduce(Decimal(0)) { $0 + $1.monto }
        let desc = b.conceptos(de: .descuento).reduce(Decimal(0)) { $0 + $1.monto }
        #expect(rem == b.totalRemuneraciones)
        #expect(desc == b.totalDescuentos)
        #expect(b.conceptos(de: .remuneracion).count == 4)
        #expect(b.conceptos(de: .descuento).count == 5)
        #expect(b.conceptos(de: .aportacionEmpleador).count == 1)
    }

    @Test("ONP y AFP nunca se aplican a la vez")
    func pensionExclusiva() throws {
        let onp = try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: true, sistema: .onp))
        #expect(onp.onp > 0)
        #expect(onp.afpFondo + onp.afpComision + onp.afpSeguro == 0)

        let afp = try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: true, sistema: .afp))
        #expect(afp.onp == 0)
        #expect(afp.afpFondo > 0 && afp.afpComision > 0 && afp.afpSeguro > 0)
    }

    @Test("La asignación familiar no se prorratea por días")
    func asignacionSinProrrateo() throws {
        let b = try Boleta(datos: datos(sueldo: "1800", dias: 1, hijos: true, sistema: .onp))
        #expect(b.asignacionFamiliar == d("123.00"))
        #expect(b.sueldoComputable == d("60.00"))
    }

    @Test("Días límite 1 y 30")
    func diasLimite() throws {
        #expect(try Boleta(datos: datos(sueldo: "3000", dias: 1, hijos: false, sistema: .onp)).sueldoComputable == d("100.00"))
        #expect(try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: false, sistema: .onp)).sueldoComputable == d("3000.00"))
    }

    @Test("Días fuera de rango se rechazan también en la clase", arguments: [0, 31, -5])
    func diasInvalidos(dias: Int) {
        #expect(throws: ErrorBoleta.self) {
            try Boleta(datos: datos(sueldo: "3000", dias: dias, hijos: false, sistema: .onp))
        }
    }

    @Test("Sueldo cero o negativo se rechaza en la clase", arguments: ["0", "-100"])
    func sueldoInvalido(sueldo: String) {
        #expect(throws: ErrorBoleta.self) {
            try Boleta(datos: datos(sueldo: sueldo, dias: 30, hijos: false, sistema: .onp))
        }
    }

    @Test("Sueldo con céntimos")
    func sueldoConCentimos() throws {
        let b = try Boleta(datos: datos(sueldo: "2500.55", dias: 15, hijos: false, sistema: .onp))
        #expect(b.sueldoComputable == d("1250.28"))   // 1250.275 → 1250.28
        #expect(b.onp == d("162.54"))                 // 162.5364
        #expect(b.netoAPagar == d("1087.74"))
    }

    @Test("Solo horas extras al 25%")
    func soloHoras25() throws {
        let b = try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: false, sistema: .onp, h25: 3))
        #expect(b.horasExtras25 == d("46.88"))        // 12.50 × 1.25 × 3 = 46.875
        #expect(b.horasExtras35 == 0)
    }

    @Test("Solo horas extras al 35%")
    func soloHoras35() throws {
        let b = try Boleta(datos: datos(sueldo: "3000", dias: 30, hijos: false, sistema: .onp, h35: 3))
        #expect(b.horasExtras25 == 0)
        #expect(b.horasExtras35 == d("50.63"))        // 12.50 × 1.35 × 3 = 50.625
    }

    @Test("El valor hora se redondea antes de calcular las horas extras")
    func valorHoraRedondeado() throws {
        let b = try Boleta(datos: datos(sueldo: "2500", dias: 30, hijos: false, sistema: .onp, h25: 1))
        #expect(b.valorHora == d("10.42"))            // 10.41666…
        #expect(b.horasExtras25 == d("13.03"))        // 10.42 × 1.25 = 13.025
    }

    @Test("Comisión y seguro con más de dos decimales se redondean por separado")
    func redondeoAFP() throws {
        let b = try Boleta(datos: datos(sueldo: "1234.56", dias: 30, hijos: false, sistema: .afp))
        #expect(b.totalRemuneraciones == d("1234.56"))
        #expect(b.afpFondo == d("123.46"))            // 123.456
        #expect(b.afpComision == d("19.75"))          // 19.75296
        #expect(b.afpSeguro == d("16.67"))            // 16.66656
        #expect(b.totalDescuentos == d("159.88"))
        #expect(b.essalud == d("111.11"))             // 111.1104
    }

    @Test("Adelanto igual al neto deja el neto en cero")
    func adelantoIgualAlNeto() throws {
        let b = try Boleta(datos: datos(sueldo: "2500", dias: 30, hijos: false, sistema: .onp, adelanto: "2175"))
        #expect(b.netoAPagar == 0)
        #expect(!b.netoEsNegativo)
    }

    @Test("Adelanto superior al neto se resta tal cual y queda marcado")
    func adelantoSuperiorAlNeto() throws {
        let b = try Boleta(datos: datos(sueldo: "2500", dias: 30, hijos: false, sistema: .onp, adelanto: "3000"))
        #expect(b.adelantos == d("3000.00"))
        #expect(b.netoAPagar == d("-825.00"))
        #expect(b.netoEsNegativo)
    }

    @Test("Valores muy grandes dentro del límite son representables")
    func valoresGrandes() throws {
        let b = try Boleta(datos: datos(sueldo: "10000000", dias: 30, hijos: true, sistema: .afp,
                                        h25: 720, h35: 720, adelanto: "10000000"))
        #expect(b.netoAPagar.isFinite)
        // 10,000,000 + 123 + 37,500,003.00 + 40,500,003.24 (valor hora 41,666.67)
        #expect(b.totalRemuneraciones == d("88000129.24"))
    }

    @Test("Sueldo por encima del límite se rechaza")
    func sueldoExcesivo() {
        #expect(throws: ErrorBoleta.self) {
            try Boleta(datos: datos(sueldo: "10000000.01", dias: 30, hijos: false, sistema: .onp))
        }
    }

    @Test("Una AFP sin tasas bloquea el cálculo en vez de usar cero")
    func afpSinTasas() {
        var sinTasas = datos(sueldo: "3000", dias: 30, hijos: false, sistema: .afp)
        sinTasas.nombreAFP = "AFP Desconocida"
        #expect(throws: ErrorBoleta.tasasAFPNoConfiguradas("AFP Desconocida")) {
            try Boleta(datos: sinTasas)
        }
    }

    // MARK: Tasas reales (SBS, devengue octubre 2026)

    private func datosReales(afp: String, sueldo: String = "3000", hijos: Bool = true,
                             h25: Int = 4, h35: Int = 4, adelanto: String = "200") -> DatosTrabajador {
        DatosTrabajador(sueldoBasico: d(sueldo), diasLaborados: 30, tieneHijos: hijos,
                        sistemaPensiones: .afp, nombreAFP: afp,
                        horasExtras25: h25, horasExtras35: h35, adelantos: d(adelanto))
    }

    @Test("Tasas SBS de comisión por flujo y prima de seguro", arguments: [
        ("AFP Habitat · Flujo", "0.0147"), ("AFP Integra · Flujo", "0.0155"),
        ("AFP Prima · Flujo", "0.0160"), ("AFP Profuturo · Flujo", "0.0169")
    ])
    func tasasReales(afp: String, comision: String) throws {
        let tasas = try #require(ParametrosLaborales.tasasAFP[afp])
        #expect(tasas.fondo == d("0.10"))
        #expect(tasas.comision == d(comision))
        #expect(tasas.seguro == d("0.0137"))
        #expect(ParametrosLaborales.tasasAFP[afp.replacingOccurrences(of: "Flujo", with: "Mixta")]?.comision == 0)
    }

    @Test("Datos del caso 3 con AFP Habitat por flujo")
    func caso3HabitatFlujo() throws {
        let b = try Boleta(datos: datosReales(afp: "AFP Habitat · Flujo"))
        #expect(b.totalRemuneraciones == d("3253.00"))
        #expect(b.afpFondo == d("325.30"))
        #expect(b.afpComision == d("47.82"))           // 3253 × 1.47% = 47.8191
        #expect(b.afpSeguro == d("44.57"))             // 3253 × 1.37% = 44.5661
        #expect(b.totalDescuentos == d("617.69"))
        #expect(b.netoAPagar == d("2635.31"))
        #expect(b.essalud == d("292.77"))
    }

    @Test("Comisión mixta: no se descuenta comisión en la boleta")
    func caso3HabitatMixta() throws {
        let b = try Boleta(datos: datosReales(afp: "AFP Habitat · Mixta"))
        #expect(b.afpComision == 0)
        #expect(b.afpSeguro == d("44.57"))
        #expect(b.totalDescuentos == d("569.87"))
        #expect(b.netoAPagar == d("2683.13"))
    }

    @Test("La prima de seguro se calcula solo hasta la remuneración máxima asegurable")
    func topeSeguro() throws {
        let b = try Boleta(datos: datosReales(afp: "AFP Prima · Flujo", sueldo: "20000",
                                              hijos: false, h25: 0, h35: 0, adelanto: "0"))
        #expect(b.totalRemuneraciones == d("20000.00"))
        #expect(b.afpFondo == d("2000.00"))            // el fondo no tiene tope
        #expect(b.afpComision == d("320.00"))          // la comisión no tiene tope
        #expect(b.afpSeguro == d("174.44"))            // 12,732.70 × 1.37% = 174.43799
        #expect(b.netoAPagar == d("17505.56"))
    }

    @Test("Formato de moneda es_PE")
    func formato() {
        // Foundation separa "S/" del importe con un espacio no separable (U+00A0).
        func normalizado(_ texto: String) -> String { texto.replacingOccurrences(of: "\u{00A0}", with: " ") }
        #expect(normalizado(d("2175").formatoSoles) == "S/ 2,175.00")
        #expect(normalizado(d("1234567.5").formatoSoles) == "S/ 1,234,567.50")
        #expect(d("0.016").formatoPorcentaje == "1.60%")
    }
}
