package com.techcare.backend.facturacion;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

@Service
public class FacturacionServicio {
    private final JdbcTemplate jdbc;
    public FacturacionServicio(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public Factura consultar(int actor, int id) {
        idValido(id);
        return primera(jdbc.queryForList("EXEC dbo.spConsultarFacturaOrden ?, ?", actor, id));
    }
    public Previa previa(int actor, int id, BigDecimal tasa) {
        idValido(id);
        if (tasa == null || tasa.signum() < 0 || tasa.compareTo(BigDecimal.ONE) > 0 || tasa.stripTrailingZeros().scale() > 4)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La tasa debe estar entre cero y uno, con hasta cuatro decimales.");
        var filas = jdbc.queryForList("EXEC dbo.spPreviaFacturaOrden ?, ?, ?", actor, id, tasa);
        if (filas.isEmpty()) throw new ResponseStatusException(HttpStatus.CONFLICT, "La orden no está disponible para facturar.");
        var r = filas.get(0);
        return new Previa(entero(r,"OrdenID"), texto(r,"NumeroOrden"), texto(r,"NITFacturacion"), texto(r,"NombreFacturacion"),
                texto(r,"DireccionFacturacion"), decimal(r,"TasaImpuesto"), decimal(r,"Subtotal"), decimal(r,"Impuesto"),
                decimal(r,"Total"), texto(r,"Revision"), filas.stream().map(FacturacionServicio::detalle).toList());
    }
    public Factura emitir(int actor, int id, FacturacionController.Emision d) {
        idValido(id);
        return primera(jdbc.queryForList("EXEC dbo.spEmitirFacturaOrden ?, ?, ?, ?", actor, id, d.tasaImpuesto(), d.revision()));
    }
    public Factura abonar(int actor, int id, FacturacionController.Abono d) {
        idValido(id);
        return primera(jdbc.queryForList("EXEC dbo.spAbonarFacturaOrden ?, ?, ?, ?, ?, ?, ?", actor, id,
                d.solicitudId().toString(), d.metodoPagoId().intValueExact(), d.monto(), d.saldoEsperado(), d.referencia()));
    }
    public List<Detalle> detalles(int actor, int id) {
        idValido(id);
        return jdbc.queryForList("EXEC dbo.spDetalleFacturaOrden ?, ?", actor, id).stream().map(FacturacionServicio::detalle).toList();
    }
    public List<Pago> pagos(int actor, int id) {
        idValido(id);
        return jdbc.queryForList("EXEC dbo.spPagosFacturaOrden ?, ?", actor, id).stream().map(r -> new Pago(
                r.get("PagoID") instanceof Number n ? n.longValue() : null, fecha(r,"Fecha"), entero(r,"MetodoPagoID"),
                texto(r,"MetodoPago"), decimal(r,"Monto"), texto(r,"Referencia"), texto(r,"RegistradoPor"))).toList();
    }
    public Entrega entrega(int actor, int id) {
        idValido(id);
        return primeraEntrega(jdbc.queryForList("EXEC dbo.spConsultarEntregaOrden ?, ?", actor, id));
    }
    public Entrega entregar(int actor, int id, FacturacionController.Recepcion d) {
        idValido(id);
        return primeraEntrega(jdbc.queryForList("EXEC dbo.spRegistrarEntregaOrden ?, ?, ?, ?, ?", actor, id,
                d.nombreRecibe(), d.documentoRecibe(), d.observaciones()));
    }
    public List<Metodo> metodos(int actor) {
        return jdbc.queryForList("EXEC dbo.spMetodosPagoCaja ?", actor).stream()
                .map(r -> new Metodo(entero(r,"MetodoPagoID"), texto(r,"Nombre"))).toList();
    }
    public List<FilaCaja> listar(int actor, String buscar, String estadoPago) {
        if (buscar != null && buscar.length() > 150) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La búsqueda admite hasta 150 caracteres.");
        return jdbc.queryForList("EXEC dbo.spListarCaja ?, ?, ?", actor, buscar, estadoPago).stream().map(r -> new FilaCaja(
                entero(r,"OrdenID"), texto(r,"NumeroOrden"), texto(r,"Cliente"), texto(r,"NumeroSerie"), texto(r,"EstadoCodigo"),
                entero(r,"FacturaID"), texto(r,"NumeroFactura"), fecha(r,"Fecha"), decimal(r,"Total"), decimal(r,"Pagado"),
                decimal(r,"Saldo"), texto(r,"EstadoPago"))).toList();
    }

    // Una lectura serializable impide mezclar un saldo con una lista de pagos de otro instante.
    // La transacción termina antes de componer el PDF o enviarlo al navegador.
    @Transactional(readOnly = true, isolation = Isolation.SERIALIZABLE)
    public Documento documento(int actor, int id) {
        Factura f = consultar(actor, id);
        if (f == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "La orden todavía no tiene factura.");
        return new Documento(f, detalles(actor,id), pagos(actor,id), entrega(actor,id));
    }
    static void idValido(int id) {
        if (id <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El ID de orden no es válido.");
    }
    private static Factura primera(List<Map<String,Object>> filas) {
        if (filas.isEmpty()) return null;
        var r = filas.get(0);
        return new Factura(entero(r,"FacturaID"), texto(r,"NumeroFactura"), entero(r,"OrdenID"), texto(r,"NumeroOrden"),
                fecha(r,"Fecha"), texto(r,"Estado"), texto(r,"NITFacturacion"), texto(r,"NombreFacturacion"), texto(r,"DireccionFacturacion"),
                decimal(r,"TasaImpuesto"), decimal(r,"Subtotal"), decimal(r,"ManoObra"), decimal(r,"Repuestos"), decimal(r,"Impuesto"),
                decimal(r,"Total"), decimal(r,"Pagado"), decimal(r,"Saldo"), texto(r,"EstadoPago"), texto(r,"NumeroSerie"),
                texto(r,"EquipoDescripcion"), texto(r,"Marca"), texto(r,"Modelo"), texto(r,"DescripcionTrabajo"),
                texto(r,"EmitidaPor"), texto(r,"Tecnico"), texto(r,"Recepcionista"));
    }
    private static Detalle detalle(Map<String,Object> r) {
        return new Detalle(entero(r,"Linea"), texto(r,"TipoConcepto"), texto(r,"Concepto"), entero(r,"Cantidad"),
                decimal(r,"PrecioUnitario"), decimal(r,"Importe"));
    }
    private static Entrega primeraEntrega(List<Map<String,Object>> filas) {
        if (filas.isEmpty()) return null;
        var r = filas.get(0);
        return new Entrega(entero(r,"OrdenID"), fecha(r,"Fecha"), texto(r,"NombreRecibe"), texto(r,"DocumentoRecibe"),
                texto(r,"Observaciones"), texto(r,"EntregadaPor"));
    }
    private static String texto(Map<String,Object> r,String k) { return r.get(k) == null ? null : r.get(k).toString(); }
    private static Integer entero(Map<String,Object> r,String k) { return r.get(k) instanceof Number n ? n.intValue() : null; }
    private static BigDecimal decimal(Map<String,Object> r,String k) { return r.get(k) instanceof BigDecimal n ? n : r.get(k) instanceof Number n ? new BigDecimal(n.toString()) : null; }
    private static OffsetDateTime fecha(Map<String,Object> r,String k) {
        Object v = r.get(k);
        if (v instanceof Timestamp t) return t.toLocalDateTime().atOffset(ZoneOffset.UTC);
        if (v instanceof LocalDateTime t) return t.atOffset(ZoneOffset.UTC);
        return v instanceof OffsetDateTime t ? t : null;
    }
    public record Factura(Integer facturaId, String numeroFactura, Integer ordenId, String numeroOrden, OffsetDateTime fecha,
            String estado, String nitFacturacion, String nombreFacturacion, String direccionFacturacion, BigDecimal tasaImpuesto,
            BigDecimal subtotal, BigDecimal manoObra, BigDecimal repuestos, BigDecimal impuesto, BigDecimal total, BigDecimal pagado,
            BigDecimal saldo, String estadoPago, String numeroSerie, String equipoDescripcion, String marca, String modelo,
            String descripcionTrabajo, String emitidaPor, String tecnico, String recepcionista) {}
    public record Detalle(Integer linea, String tipoConcepto, String concepto, Integer cantidad, BigDecimal precioUnitario, BigDecimal importe) {}
    public record Previa(Integer ordenId, String numeroOrden, String nitFacturacion, String nombreFacturacion,
            String direccionFacturacion, BigDecimal tasaImpuesto, BigDecimal subtotal, BigDecimal impuesto, BigDecimal total,
            String revision, List<Detalle> detalles) {}
    public record Pago(Long pagoId, OffsetDateTime fecha, Integer metodoPagoId, String metodoPago, BigDecimal monto, String referencia, String registradoPor) {}
    public record Entrega(Integer ordenId, OffsetDateTime fecha, String nombreRecibe, String documentoRecibe, String observaciones, String entregadaPor) {}
    public record Metodo(Integer metodoPagoId, String nombre) {}
    public record FilaCaja(Integer ordenId, String numeroOrden, String cliente, String numeroSerie, String estadoCodigo,
            Integer facturaId, String numeroFactura, OffsetDateTime fecha, BigDecimal total, BigDecimal pagado, BigDecimal saldo, String estadoPago) {}
    public record Documento(Factura factura, List<Detalle> detalles, List<Pago> pagos, Entrega entrega) {}
}
