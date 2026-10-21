import { descargarPdf, http } from "./http";

export interface Factura {
  facturaId: number; numeroFactura: string; ordenId: number; numeroOrden: string; fecha: string; estado: string;
  nitFacturacion: string; nombreFacturacion: string; direccionFacturacion: string | null; tasaImpuesto: number;
  subtotal: number; manoObra: number; repuestos: number; impuesto: number; total: number; pagado: number; saldo: number;
  estadoPago: string; numeroSerie: string; equipoDescripcion: string; marca: string; modelo: string;
  descripcionTrabajo: string; emitidaPor: string; tecnico: string; recepcionista: string;
}
export interface DetalleFactura { linea: number; tipoConcepto: string; concepto: string; cantidad: number; precioUnitario: number; importe: number }
export interface PreviaFactura {
  ordenId: number; numeroOrden: string; nitFacturacion: string; nombreFacturacion: string; direccionFacturacion: string | null;
  tasaImpuesto: number; subtotal: number; impuesto: number; total: number; revision: string; detalles: DetalleFactura[];
}
export interface PagoFactura { pagoId: number; fecha: string; metodoPagoId: number; metodoPago: string; monto: number; referencia: string | null; registradoPor: string }
export interface EntregaOrden { ordenId: number; fecha: string; nombreRecibe: string; documentoRecibe: string | null; observaciones: string | null; entregadaPor: string }
export interface Abono { solicitudId: string; metodoPagoId: number; monto: string; saldoEsperado: number; referencia: string | null }
export interface FilaCaja {
  ordenId: number; numeroOrden: string; cliente: string; numeroSerie: string; estadoCodigo: string;
  facturaId: number | null; numeroFactura: string | null; fecha: string | null; total: number | null;
  pagado: number | null; saldo: number | null; estadoPago: string;
}
const base = (id: number) => `/ordenes/${id}`;
export const facturacionApi = {
  listar: (buscar: string, estadoPago: string, signal?: AbortSignal) => http.get<FilaCaja[]>(`/facturas?${new URLSearchParams({ buscar, estadoPago })}`, signal),
  consultar: (id: number, signal?: AbortSignal) => http.get<Factura | null>(`${base(id)}/factura`, signal),
  previa: (id: number, tasa: string, signal?: AbortSignal) => http.get<PreviaFactura>(`${base(id)}/factura/previa?${new URLSearchParams({ tasaImpuesto: tasa })}`, signal),
  emitir: (id: number, tasaImpuesto: number, revision: string) => http.post<Factura>(`${base(id)}/factura`, { tasaImpuesto, revision }),
  detalles: (id: number, signal?: AbortSignal) => http.get<DetalleFactura[]>(`${base(id)}/factura/detalles`, signal),
  pagos: (id: number, signal?: AbortSignal) => http.get<PagoFactura[]>(`${base(id)}/factura/pagos`, signal),
  abonar: (id: number, datos: Abono) => http.post<Factura>(`${base(id)}/factura/pagos`, datos),
  metodos: (signal?: AbortSignal) => http.get<{ metodoPagoId: number; nombre: string }[]>("/caja/metodos-pago", signal),
  entrega: (id: number, signal?: AbortSignal) => http.get<EntregaOrden | null>(`${base(id)}/entrega`, signal),
  entregar: (id: number, nombreRecibe: string, documentoRecibe: string, observaciones: string) => http.post<EntregaOrden>(`${base(id)}/entrega`, { nombreRecibe, documentoRecibe, observaciones }),
  pdf: (id: number) => descargarPdf(`${base(id)}/factura/pdf`),
};
export const estadoCobro = (estado: string) => ({ SIN_FACTURA: "Sin factura", PENDIENTE: "Pendiente de pago", PARCIAL: "Pago parcial", PAGADA: "Pagada", ANULADA: "Anulada" }[estado] ?? estado);
