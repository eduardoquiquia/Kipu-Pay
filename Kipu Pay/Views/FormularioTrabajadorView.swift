//
//  FormularioTrabajadorView.swift
//  Kipu Pay
//

import SwiftUI

struct FormularioTrabajadorView: View {
    @Bindable var viewModel: BoletaViewModel
    var foco: FocusState<Campo?>.Binding

    var body: some View {
        VStack(spacing: 16) {
            Tarjeta {
                TituloSeccion(icono: "person.text.rectangle",
                              titulo: "Datos del mes",
                              descripcion: "Lo que pactaste con la empresa y los días que trabajaste.")
                CampoNumerico(titulo: "Sueldo básico",
                              ayuda: "Monto mensual. Usa punto para los céntimos.",
                              prefijo: "S/", placeholder: "Ej. 2500.00",
                              texto: $viewModel.entrada.sueldo, teclado: .decimalPad,
                              campo: .sueldo, foco: foco, error: viewModel.error(para: .sueldo))
                CampoNumerico(titulo: "Días laborados",
                              ayuda: "Entre 1 y 30. Las faltas ya se reflejan aquí.",
                              sufijo: "de 30", placeholder: "Ej. 30",
                              texto: $viewModel.entrada.dias, teclado: .numberPad,
                              campo: .dias, foco: foco, error: viewModel.error(para: .dias))
                SelectorSegmentado(titulo: "¿Tiene hijos?",
                                   seleccion: $viewModel.entrada.tieneHijos,
                                   opciones: [(false, "No"), (true, "Sí")])
            }

            Tarjeta {
                TituloSeccion(icono: "building.columns",
                              titulo: "Sistema de pensiones",
                              descripcion: "Se aplica solo uno: ONP o AFP.")
                SelectorSegmentado(titulo: "Sistema",
                                   seleccion: $viewModel.entrada.sistemaPensiones.animation(.easeInOut(duration: 0.25)),
                                   opciones: SistemaPensiones.allCases.map { ($0, $0.rawValue) })
                if viewModel.entrada.sistemaPensiones == .afp {
                    selectorAFP
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Tarjeta {
                TituloSeccion(icono: "clock",
                              titulo: "Opciones adicionales",
                              descripcion: "Horas extras y adelantos. Déjalos en 0 si no aplican.")
                HStack(alignment: .top, spacing: 12) {
                    CampoNumerico(titulo: "H. extras 25%",
                                  sufijo: "h", placeholder: "0",
                                  texto: $viewModel.entrada.horas25, teclado: .numberPad,
                                  campo: .horas25, foco: foco, error: viewModel.error(para: .horas25))
                    CampoNumerico(titulo: "H. extras 35%",
                                  sufijo: "h", placeholder: "0",
                                  texto: $viewModel.entrada.horas35, teclado: .numberPad,
                                  campo: .horas35, foco: foco, error: viewModel.error(para: .horas35))
                }
                Text("Horas enteras, ya separadas por recargo.")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
                CampoNumerico(titulo: "Adelantos",
                              ayuda: "Se resta tal cual del neto.",
                              prefijo: "S/", placeholder: "0.00",
                              texto: $viewModel.entrada.adelantos, teclado: .decimalPad,
                              campo: .adelantos, foco: foco, error: viewModel.error(para: .adelantos))
            }
        }
    }

    private var selectorAFP: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AFP")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Paleta.textoPrincipal)
                Spacer()
                Picker("AFP", selection: $viewModel.entrada.afp) {
                    ForEach(viewModel.afpsDisponibles, id: \.self) { nombre in
                        Text(nombre).tag(nombre)
                    }
                }
                .pickerStyle(.menu)
                .tint(Paleta.verde)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Paleta.superficieElevada, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let tasas = viewModel.tasasAFPSeleccionada {
                Text("Fondo \(tasas.fondo.formatoPorcentaje) · Comisión \(tasas.comision.formatoPorcentaje) · Seguro \(tasas.seguro.formatoPorcentaje)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Paleta.textoSecundario)
                Text("Valores de prueba del laboratorio, no tasas oficiales.")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
            }
            if let error = viewModel.error(para: .afp) {
                MensajeEstado(tipo: .error, texto: error)
            }
        }
    }
}
