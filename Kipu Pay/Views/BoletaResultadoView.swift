//
//  BoletaResultadoView.swift
//  Kipu Pay
//
//  Presenta la boleta calculada. No calcula nada: solo lee `Boleta`.
//

import SwiftUI

struct BoletaResultadoView: View {
    let boleta: Boleta
    let desactualizada: Bool
    let revisada: Bool
    let alRevisar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tu boleta")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Paleta.textoPrincipal)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Etiqueta(texto: "EJEMPLO ACADÉMICO")
            }

            if desactualizada {
                Tarjeta(relleno: Paleta.superficieElevada) {
                    MensajeEstado(tipo: .aviso,
                                  texto: "Cambiaste datos después de calcular. Estos importes ya no corresponden al formulario: pulsa Recalcular.")
                }
                .transition(.opacity)
            }

            Group {
                bloque(icono: "banknote", titulo: "A · Remuneraciones",
                       tipo: .remuneracion, total: ("Total remuneraciones", boleta.totalRemuneraciones)) {
                    FilaImporte(nombre: "Valor por hora", detalle: "Referencia: básico ÷ 30 ÷ 8",
                                monto: boleta.valorHora, estilo: .informativo)
                }
                bloque(icono: "minus.circle", titulo: "B · Retenciones y descuentos",
                       tipo: .descuento, total: ("Total descuentos", boleta.totalDescuentos))
                bloque(icono: "building.2", titulo: "C · Aportaciones del empleador",
                       tipo: .aportacionEmpleador, total: nil)

                netoAPagar
            }
            .opacity(desactualizada ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.2), value: desactualizada)

            botonRevision
        }
    }

    // MARK: - Bloques

    private func bloque(icono: String, titulo: String, tipo: TipoConcepto,
                        total: (String, Decimal)?,
                        @ViewBuilder extra: () -> some View = { EmptyView() }) -> some View {
        Tarjeta {
            TituloSeccion(icono: icono, titulo: titulo)
            VStack(spacing: 12) {
                ForEach(boleta.conceptos(de: tipo)) { concepto in
                    FilaImporte(nombre: concepto.nombre, detalle: concepto.detalle,
                                monto: concepto.monto, estilo: concepto.aplica ? .normal : .noAplica)
                }
                extra()
                if let total {
                    Divider().overlay(Paleta.borde)
                    FilaImporte(nombre: total.0, detalle: nil, monto: total.1, estilo: .total)
                }
            }
        }
    }

    private var netoAPagar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NETO A PAGAR")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Paleta.textoSecundario)
            Text(boleta.netoAPagar.formatoSoles)
                .font(.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(desactualizada ? Paleta.textoSecundario
                                 : (boleta.netoEsNegativo ? Paleta.aviso : Paleta.verde))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text("Total remuneraciones − total descuentos. EsSalud lo paga el empleador y no se descuenta.")
                .font(.footnote)
                .foregroundStyle(Paleta.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            if boleta.netoEsNegativo {
                MensajeEstado(tipo: .aviso,
                              texto: "Los adelantos superan lo que corresponde pagar. Es el resultado matemático del ejercicio; este caso requiere revisión y no confirma que el descuento sea legal en una situación real.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficieElevada, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(colorBordeNeto, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Neto a pagar: \(boleta.netoAPagar.formatoSoles)\(desactualizada ? ", desactualizado" : "")")
        .id("neto")
    }

    private var colorBordeNeto: Color {
        if desactualizada { return Paleta.borde }
        return boleta.netoEsNegativo ? Paleta.aviso.opacity(0.7) : Paleta.verde.opacity(0.7)
    }

    @ViewBuilder
    private var botonRevision: some View {
        if revisada && !desactualizada {
            Label("Boleta revisada", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paleta.verde)
                .frame(maxWidth: .infinity, minHeight: 48)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else {
            Button(action: alRevisar) {
                Label("Marcar como revisada", systemImage: "checkmark.circle")
            }
            .buttonStyle(EstiloBotonSecundario())
            .disabled(desactualizada)
            .opacity(desactualizada ? 0.4 : 1)
            .accessibilityHint(desactualizada ? "Recalcula la boleta antes de marcarla como revisada." : "Completa la etapa de revisión.")
        }
    }
}

// MARK: - Fila de importe

struct FilaImporte: View {
    enum Estilo { case normal, noAplica, informativo, total }

    let nombre: String
    let detalle: String?
    let monto: Decimal
    let estilo: Estilo

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(nombre)
                    .font(estilo == .total ? .subheadline.weight(.bold) : .subheadline)
                    .foregroundStyle(estilo == .normal || estilo == .total ? Paleta.textoPrincipal : Paleta.textoSecundario)
                if let detalle, !detalle.isEmpty {
                    Text(detalle)
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(monto.formatoSoles)
                .font((estilo == .total ? Font.body.weight(.bold) : Font.body).monospacedDigit())
                .foregroundStyle(estilo == .noAplica || estilo == .informativo ? Paleta.textoSecundario : Paleta.textoPrincipal)
                .italic(estilo == .informativo)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nombre): \(monto.formatoSoles)\(estilo == .noAplica ? ", no aplica" : "")")
    }
}
