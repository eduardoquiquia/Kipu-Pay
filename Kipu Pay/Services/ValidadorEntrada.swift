//
//  ValidadorEntrada.swift
//  Kipu Pay
//
//  Convierte el texto de los TextField en números. Una entrada inválida nunca se
//  convierte en cero: devuelve un mensaje que se muestra junto al campo.
//

import Foundation

struct ErrorCampo: Error, Equatable {
    let mensaje: String
}

enum ValidadorEntrada {

    private static let digitos = Set("0123456789")

    /// Importe en soles: cifras con un separador decimal opcional ("." o ",") y hasta 2 decimales.
    /// Si el campo es opcional, vacío equivale a cero.
    static func monto(_ texto: String, obligatorio: Bool, permiteCero: Bool = true) -> Result<Decimal, ErrorCampo> {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpio.isEmpty {
            return obligatorio ? .failure(ErrorCampo(mensaje: "Este campo es obligatorio.")) : .success(0)
        }
        if limpio.hasPrefix("-") {
            return .failure(ErrorCampo(mensaje: "No puede ser negativo."))
        }

        let partes = limpio.split(omittingEmptySubsequences: false) { $0 == "." || $0 == "," }
        guard partes.count <= 2,
              let entera = partes.first, !entera.isEmpty, entera.allSatisfy(digitos.contains),
              partes.count == 1 || (!partes[1].isEmpty && partes[1].allSatisfy(digitos.contains))
        else {
            return .failure(ErrorCampo(mensaje: "No es un número válido. Escribe solo cifras, por ejemplo 2500.50."))
        }
        if partes.count == 2, partes[1].count > 2 {
            return .failure(ErrorCampo(mensaje: "Usa como máximo 2 decimales y sin separador de miles (2500, no 2,500)."))
        }

        guard entera.count <= 12,
              let valor = Decimal(string: partes.joined(separator: "."), locale: Locale(identifier: "en_US_POSIX")),
              valor <= ParametrosLaborales.montoMaximo
        else {
            return .failure(ErrorCampo(mensaje: "No puede superar \(ParametrosLaborales.montoMaximo.formatoSoles)."))
        }
        if !permiteCero && valor == 0 {
            return .failure(ErrorCampo(mensaje: "Debe ser mayor que cero."))
        }
        return .success(valor)
    }

    /// Número entero dentro de un rango. Si el campo es opcional, vacío equivale a cero.
    static func entero(_ texto: String, obligatorio: Bool, rango: ClosedRange<Int>) -> Result<Int, ErrorCampo> {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpio.isEmpty {
            return obligatorio ? .failure(ErrorCampo(mensaje: "Este campo es obligatorio.")) : .success(0)
        }
        if limpio.hasPrefix("-") {
            return .failure(ErrorCampo(mensaje: "No puede ser negativo."))
        }
        if limpio.contains(where: { $0 == "." || $0 == "," }) {
            return .failure(ErrorCampo(mensaje: "Debe ser un número entero, sin decimales."))
        }
        guard limpio.allSatisfy(digitos.contains) else {
            return .failure(ErrorCampo(mensaje: "No es un número válido. Escribe solo cifras."))
        }
        guard limpio.count <= 6, let valor = Int(limpio), rango.contains(valor) else {
            return .failure(ErrorCampo(mensaje: "Debe estar entre \(rango.lowerBound) y \(rango.upperBound)."))
        }
        return .success(valor)
    }
}
