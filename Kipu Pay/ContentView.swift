//
//  ContentView.swift
//  Kipu Pay
//
//  Created by Gean Pierre on 28/10/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = BoletaViewModel()
    @FocusState private var campoActivo: Campo?

    private let ordenCampos: [Campo] = [.sueldo, .dias, .horas25, .horas35, .adelantos]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        encabezado
                        Tarjeta {
                            ProgresoView(etapas: [
                                EtapaProgreso(id: 1, titulo: "Datos", completa: viewModel.etapaDatosCompleta),
                                EtapaProgreso(id: 2, titulo: "Cálculo", completa: viewModel.etapaCalculoCompleta),
                                EtapaProgreso(id: 3, titulo: "Revisión", completa: viewModel.etapaRevisionCompleta)
                            ])
                        }

                        FormularioTrabajadorView(viewModel: viewModel, foco: $campoActivo)

                        seccionCalcular(proxy: proxy)

                        if let boleta = viewModel.boleta {
                            BoletaResultadoView(boleta: boleta,
                                                desactualizada: viewModel.boletaDesactualizada,
                                                revisada: viewModel.boletaRevisada) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    viewModel.marcarRevisada()
                                }
                            }
                            .id("boleta")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        notaAcademica
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Paleta.fondo.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.2), value: viewModel.erroresVisibles.map(\.campo))
                .onChange(of: campoActivo) { _, campo in
                    guard let campo else { return }
                    withAnimation { proxy.scrollTo(campo, anchor: .center) }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Anterior", systemImage: "chevron.up") { moverFoco(-1) }
                        .disabled(campoActivo == ordenCampos.first)
                    Button("Siguiente", systemImage: "chevron.down") { moverFoco(1) }
                        .disabled(campoActivo == ordenCampos.last)
                    Spacer()
                    Button("Listo") { campoActivo = nil }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(Paleta.verde)
        .sensoryFeedback(.success, trigger: viewModel.calculosExitosos)
        .sensoryFeedback(.error, trigger: viewModel.intentosFallidos)
    }

    // MARK: - Secciones

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .frame(width: 52, height: 52)
                    .background(Paleta.verde, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kipu Pay")
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(Paleta.textoPrincipal)
                    Text("Tu sueldo, explicado claramente")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            Etiqueta(texto: "BOLETA DE EJEMPLO", color: Paleta.verde)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private func seccionCalcular(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.erroresVisibles.isEmpty {
                Tarjeta(relleno: Paleta.superficieElevada) {
                    MensajeEstado(tipo: .error,
                                  texto: viewModel.erroresVisibles.count == 1
                                  ? "Corrige 1 campo para poder calcular:"
                                  : "Corrige \(viewModel.erroresVisibles.count) campos para poder calcular:")
                    ForEach(viewModel.erroresVisibles, id: \.campo) { error in
                        Text("• \(error.campo.etiqueta): \(error.mensaje)")
                            .font(.footnote)
                            .foregroundStyle(Paleta.textoPrincipal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity)
            }
            if let error = viewModel.errorCalculo {
                Tarjeta(relleno: Paleta.superficieElevada) {
                    MensajeEstado(tipo: .error, texto: error)
                }
            }

            Button {
                campoActivo = nil
                let exito = withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.calcular()
                }
                if exito {
                    withAnimation(.easeInOut(duration: 0.4).delay(0.1)) {
                        proxy.scrollTo("boleta", anchor: .top)
                    }
                } else if let primero = viewModel.erroresVisibles.first?.campo {
                    withAnimation { proxy.scrollTo(primero, anchor: .center) }
                }
            } label: {
                Label(viewModel.boleta == nil ? "Calcular" : "Recalcular",
                      systemImage: viewModel.boleta == nil ? "equal.circle.fill" : "arrow.clockwise.circle.fill")
            }
            .buttonStyle(EstiloBotonPrincipal())
            .accessibilityHint("Calcula la boleta con los datos del formulario.")
        }
    }

    private var notaAcademica: some View {
        Label {
            Text("Simulación académica. Las tasas usadas, incluida AFP Ejemplo, son valores del laboratorio: verifícalas en fuentes oficiales (SBS, El Peruano) antes de usarlas en una boleta laboral real.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(Paleta.textoSecundario)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    private func moverFoco(_ paso: Int) {
        guard let actual = campoActivo, let indice = ordenCampos.firstIndex(of: actual) else { return }
        let siguiente = indice + paso
        guard ordenCampos.indices.contains(siguiente) else { return }
        campoActivo = ordenCampos[siguiente]
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
