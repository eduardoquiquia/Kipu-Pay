//
//  FormularioTests.swift
//  Kipu PayTests
//
//  Validación de entradas y estado del formulario (BoletaViewModel).
//

import Foundation
import Testing
@testable import Kipu_Pay

private func d(_ texto: String) -> Decimal {
    Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX"))!
}

@MainActor
@Suite("Validación de entradas")
struct ValidadorEntradaTests {

    @Test("Montos válidos", arguments: [
        ("2500", "2500"), ("2500.50", "2500.50"), ("2500,50", "2500.50"),
        ("  3000  ", "3000"), ("0.5", "0.5"), ("10000000", "10000000")
    ])
    func montosValidos(texto: String, esperado: String) throws {
        #expect(try ValidadorEntrada.monto(texto, obligatorio: true).get() == d(esperado))
    }

    @Test("Montos inválidos nunca se convierten en cero", arguments: [
        "abc", "2,500.00", "2,500", "12.345", "1.2.3", "25 00", "2500.", ".50", "-100", "10000000.01", "1e5"
    ])
    func montosInvalidos(texto: String) {
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.monto(texto, obligatorio: true).get() }
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.monto(texto, obligatorio: false).get() }
    }

    @Test("Sueldo vacío o cero se rechaza")
    func sueldoVacioOCero() {
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.monto("", obligatorio: true, permiteCero: false).get() }
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.monto("   ", obligatorio: true, permiteCero: false).get() }
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.monto("0", obligatorio: true, permiteCero: false).get() }
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.monto("0.00", obligatorio: true, permiteCero: false).get() }
    }

    @Test("Campo opcional vacío equivale a cero")
    func opcionalVacio() throws {
        #expect(try ValidadorEntrada.monto("", obligatorio: false).get() == 0)
        #expect(try ValidadorEntrada.entero(" ", obligatorio: false, rango: 0...720).get() == 0)
    }

    @Test("Días válidos", arguments: [("1", 1), ("30", 30), (" 15 ", 15)])
    func diasValidos(texto: String, esperado: Int) throws {
        #expect(try ValidadorEntrada.entero(texto, obligatorio: true, rango: 1...30).get() == esperado)
    }

    @Test("Días inválidos", arguments: ["", "0", "31", "-1", "15.5", "15,0", "quince", "99999999999"])
    func diasInvalidos(texto: String) {
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.entero(texto, obligatorio: true, rango: 1...30).get() }
    }

    @Test("Horas extras negativas o decimales se rechazan", arguments: ["-2", "1.5", "721"])
    func horasInvalidas(texto: String) {
        #expect(throws: ErrorCampo.self) { try ValidadorEntrada.entero(texto, obligatorio: false, rango: 0...720).get() }
    }

    @Test("El mensaje de días decimales es específico")
    func mensajeDecimales() {
        let resultado = ValidadorEntrada.entero("27.5", obligatorio: true, rango: 1...30)
        #expect(resultado == .failure(ErrorCampo(mensaje: "Debe ser un número entero, sin decimales.")))
    }
}

@MainActor
@Suite("Estado del formulario")
struct BoletaViewModelTests {

    private func viewModelCaso3() -> BoletaViewModel {
        let vm = BoletaViewModel()
        vm.entrada.sueldo = "3000"
        vm.entrada.dias = "30"
        vm.entrada.tieneHijos = true
        vm.entrada.sistemaPensiones = .afp
        vm.entrada.horas25 = "4"
        vm.entrada.horas35 = "4"
        vm.entrada.adelantos = "200"
        return vm
    }

    @Test("Antes de calcular no hay boleta ni errores visibles")
    func estadoInicial() {
        let vm = BoletaViewModel()
        #expect(vm.boleta == nil)
        #expect(vm.erroresVisibles.isEmpty)
        #expect(!vm.etapaDatosCompleta && !vm.etapaCalculoCompleta && !vm.etapaRevisionCompleta)
        #expect(vm.entrada.sistemaPensiones == .onp)
        #expect(vm.entrada.tieneHijos == false)
    }

    @Test("Con errores se bloquea el cálculo y se muestran mensajes")
    func bloqueoPorErrores() {
        let vm = BoletaViewModel()
        vm.entrada.dias = "31"
        #expect(vm.calcular() == false)
        #expect(vm.boleta == nil)
        #expect(vm.error(para: .sueldo) != nil)
        #expect(vm.error(para: .dias) != nil)
        #expect(vm.erroresVisibles.map(\.campo) == [.sueldo, .dias])
    }

    @Test("Opcionales vacíos se interpretan como cero")
    func opcionalesVacios() throws {
        let vm = BoletaViewModel()
        vm.entrada.sueldo = "2500"
        vm.entrada.dias = "30"
        vm.entrada.horas25 = ""
        vm.entrada.horas35 = ""
        vm.entrada.adelantos = ""
        #expect(vm.calcular())
        let boleta = try #require(vm.boleta)
        #expect(boleta.netoAPagar == d("2175.00"))
    }

    @Test("Cambiar un dato después de calcular deja la boleta desactualizada")
    func desactualizada() {
        let vm = viewModelCaso3()
        vm.calcular()
        vm.marcarRevisada()
        #expect(vm.etapaRevisionCompleta)

        vm.entrada.adelantos = "300"
        #expect(vm.boletaDesactualizada)
        #expect(!vm.etapaCalculoCompleta)
        #expect(!vm.etapaRevisionCompleta)

        vm.calcular()
        #expect(!vm.boletaDesactualizada)
        #expect(!vm.boletaRevisada)
        #expect(vm.boleta?.adelantos == d("300.00"))
    }

    @Test("Una entrada inválida tras calcular también marca la boleta como desactualizada")
    func desactualizadaPorInvalido() {
        let vm = viewModelCaso3()
        vm.calcular()
        vm.entrada.dias = "abc"
        #expect(vm.boletaDesactualizada)
        #expect(vm.calcular() == false)
        #expect(vm.error(para: .dias) != nil)
    }

    @Test("Cambiar de AFP a ONP elimina los descuentos AFP")
    func afpAOnp() throws {
        let vm = viewModelCaso3()
        vm.calcular()
        #expect(try #require(vm.boleta).afpFondo == d("325.30"))

        vm.entrada.sistemaPensiones = .onp
        #expect(vm.boletaDesactualizada)
        vm.calcular()
        let boleta = try #require(vm.boleta)
        #expect(boleta.afpFondo == 0 && boleta.afpComision == 0 && boleta.afpSeguro == 0)
        #expect(boleta.onp == d("422.89"))            // 3253.00 × 13% = 422.89
        #expect(boleta.datos.nombreAFP == nil)
        // La AFP elegida se conserva por si el usuario vuelve a AFP.
        #expect(vm.entrada.afp == ParametrosLaborales.afpEjemplo)
    }

    @Test("Cambiar hijos actualiza la asignación al recalcular")
    func cambioHijos() throws {
        let vm = viewModelCaso3()
        vm.calcular()
        vm.entrada.tieneHijos = false
        vm.calcular()
        #expect(try #require(vm.boleta).asignacionFamiliar == 0)
        #expect(try #require(vm.boleta).totalRemuneraciones == d("3130.00"))
    }

    @Test("Calcular varias veces no duplica importes")
    func calculoRepetido() throws {
        let vm = viewModelCaso3()
        for _ in 0..<5 { vm.calcular() }
        let boleta = try #require(vm.boleta)
        #expect(boleta.totalDescuentos == d("621.27"))
        #expect(boleta.netoAPagar == d("2631.73"))
        #expect(boleta.conceptos.count == 10)
        #expect(vm.calculosExitosos == 5)
    }

    @Test("AFP sin tasas configuradas bloquea el cálculo")
    func afpSinTasas() {
        let vm = BoletaViewModel(tasasAFP: [:])
        vm.entrada.sueldo = "3000"
        vm.entrada.dias = "30"
        vm.entrada.sistemaPensiones = .afp
        #expect(vm.calcular() == false)
        #expect(vm.boleta == nil)
        #expect(vm.error(para: .afp) != nil)
    }

    @Test("No se puede marcar como revisada sin un cálculo vigente")
    func revisionSinCalculo() {
        let vm = BoletaViewModel()
        vm.marcarRevisada()
        #expect(!vm.boletaRevisada)
    }
}
