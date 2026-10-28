//
//  ComponentesUI.swift
//  Kipu Pay
//
//  Paleta y componentes visuales reutilizables.
//

import SwiftUI

// MARK: - Paleta

enum Paleta {
    static let fondo = Color(hex: 0x121212)
    static let superficie = Color(hex: 0x181818)
    static let superficieElevada = Color(hex: 0x242424)
    static let verde = Color(hex: 0x1ED760)
    static let verdeSecundario = Color(hex: 0x1DB954)
    static let textoPrincipal = Color.white
    static let textoSecundario = Color(hex: 0xB3B3B3)
    static let borde = Color(hex: 0x333333)
    /// Rojo claro con contraste suficiente sobre fondo oscuro y distinto del verde.
    static let error = Color(hex: 0xFF6B6B)
    /// Ámbar para avisos que no son errores (resultado desactualizado, neto negativo).
    static let aviso = Color(hex: 0xFFB547)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Tarjeta

struct Tarjeta<Contenido: View>: View {
    var relleno: Color = Paleta.superficie
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            contenido
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(relleno, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Paleta.borde, lineWidth: 1)
        )
    }
}

struct TituloSeccion: View {
    let icono: String
    let titulo: String
    var descripcion: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icono)
                .font(.headline)
                .foregroundStyle(Paleta.verde)
                .frame(width: 32, height: 32)
                .background(Paleta.superficieElevada, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.headline)
                    .foregroundStyle(Paleta.textoPrincipal)
                if let descripcion {
                    Text(descripcion)
                        .font(.footnote)
                        .foregroundStyle(Paleta.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct Etiqueta: View {
    let texto: String
    var color: Color = Paleta.textoSecundario

    var body: some View {
        Text(texto)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Mensajes

/// Mensaje con icono y texto: nunca depende solo del color.
struct MensajeEstado: View {
    enum Tipo { case error, aviso }

    let tipo: Tipo
    let texto: String

    private var color: Color { tipo == .error ? Paleta.error : Paleta.aviso }
    private var icono: String { tipo == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill" }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icono)
                .accessibilityHidden(true)
            Text(texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel((tipo == .error ? "Error: " : "Aviso: ") + texto)
    }
}

// MARK: - Campo numérico

struct CampoNumerico: View {
    let titulo: String
    var ayuda: String?
    var prefijo: String?
    var sufijo: String?
    let placeholder: String
    @Binding var texto: String
    let teclado: UIKeyboardType
    let campo: Campo
    var foco: FocusState<Campo?>.Binding
    var error: String?

    private var enFoco: Bool { foco.wrappedValue == campo }

    private var colorBorde: Color {
        if error != nil { return Paleta.error }
        return enFoco ? Paleta.verde : Paleta.borde
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paleta.textoPrincipal)
            HStack(spacing: 8) {
                if let prefijo {
                    Text(prefijo)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Paleta.textoSecundario)
                        .accessibilityHidden(true)
                }
                TextField(placeholder, text: $texto, prompt: Text(placeholder).foregroundStyle(Paleta.textoSecundario.opacity(0.6)))
                    .keyboardType(teclado)
                    .focused(foco, equals: campo)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Paleta.textoPrincipal)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel(titulo)
                    .accessibilityHint(ayuda ?? "")
                    .accessibilityValue(error.map { "\(texto). Error: \($0)" } ?? texto)
                if let sufijo {
                    Text(sufijo)
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Paleta.superficieElevada, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(colorBorde, lineWidth: enFoco || error != nil ? 1.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { foco.wrappedValue = campo }
            .animation(.easeOut(duration: 0.15), value: enFoco)

            if let error {
                MensajeEstado(tipo: .error, texto: error)
                    .transition(.opacity)
            } else if let ayuda {
                Text(ayuda)
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
                    .accessibilityHidden(true)
            }
        }
        .id(campo)
    }
}

// MARK: - Selector

struct SelectorSegmentado<Opcion: Hashable>: View {
    let titulo: String
    @Binding var seleccion: Opcion
    let opciones: [(valor: Opcion, texto: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paleta.textoPrincipal)
            Picker(titulo, selection: $seleccion) {
                ForEach(opciones, id: \.valor) { opcion in
                    Text(opcion.texto).tag(opcion.valor)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Botón principal

struct EstiloBotonPrincipal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                configuration.isPressed ? Paleta.verdeSecundario : Paleta.verde,
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct EstiloBotonSecundario: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Paleta.textoPrincipal)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(Capsule().stroke(Paleta.textoSecundario.opacity(configuration.isPressed ? 1 : 0.5), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Progreso

struct EtapaProgreso: Identifiable {
    let id: Int
    let titulo: String
    let completa: Bool
}

struct ProgresoView: View {
    let etapas: [EtapaProgreso]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(etapas) { etapa in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(etapa.completa ? Paleta.verde : Paleta.superficieElevada)
                        Circle()
                            .stroke(etapa.completa ? Paleta.verde : Paleta.borde, lineWidth: 1.5)
                        if etapa.completa {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Color.black)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text("\(etapa.id)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Paleta.textoSecundario)
                        }
                    }
                    .frame(width: 28, height: 28)
                    Text(etapa.titulo)
                        .font(.caption)
                        .foregroundStyle(etapa.completa ? Paleta.textoPrincipal : Paleta.textoSecundario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Etapa \(etapa.id) de \(etapas.count), \(etapa.titulo): \(etapa.completa ? "completada" : "pendiente")")

                if etapa.id < etapas.count {
                    Capsule()
                        .fill(etapa.completa ? Paleta.verde : Paleta.borde)
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                        .offset(y: -10)
                        .accessibilityHidden(true)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: etapas.map(\.completa))
    }
}
