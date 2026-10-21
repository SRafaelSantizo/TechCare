package com.techcare.backend.ordenes;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

@Service
public class ServicioTecnico {
    private final JdbcTemplate jdbc;
    private final OrdenesServicio ordenes;
    public ServicioTecnico(JdbcTemplate jdbc, OrdenesServicio ordenes) { this.jdbc = jdbc; this.ordenes = ordenes; }

    public OrdenesServicio.Orden iniciarDiagnostico(int actor, int id) {
        return ejecutar("EXEC dbo.spIniciarDiagnosticoOrden ?, ?", actor, id);
    }
    public OrdenesServicio.Orden diagnosticar(int actor, int id, ServicioTecnicoController.Diagnostico datos) {
        return ejecutar("EXEC dbo.spRegistrarDiagnosticoOrden ?, ?, ?, ?", actor, id, datos.descripcion(), datos.costoEstimado());
    }
    public OrdenesServicio.Orden reparar(int actor, int id, ServicioTecnicoController.Reparacion datos) {
        return ejecutar("EXEC dbo.spIniciarReparacionOrden ?, ?, ?, ?, ?", actor, id,
                datos.descripcionTrabajo(), datos.costoManoObra(), datos.autorizacion());
    }
    public OrdenesServicio.Orden agregarActividad(int actor, int id, ServicioTecnicoController.Actividad datos) {
        return ejecutar("EXEC dbo.spAgregarActividadOrden ?, ?, ?, ?", actor, id, datos.actividadId(), datos.observacion());
    }
    public OrdenesServicio.Orden consumir(int actor, int id, ServicioTecnicoController.Consumo datos) {
        return ejecutar("EXEC dbo.spUsarRepuestoOrden ?, ?, ?, ?, ?, ?", actor, id,
                datos.bodegaId(), datos.repuestoId(), datos.cantidad().intValueExact(), datos.precioUnitarioEsperado());
    }
    public OrdenesServicio.Orden finalizar(int actor, int id) {
        return ejecutar("EXEC dbo.spFinalizarReparacionOrden ?, ?", actor, id);
    }
    private OrdenesServicio.Orden ejecutar(String sql, int actor, int id, Object... datos) {
        OrdenesServicio.idValido(id);
        Object[] parametros = new Object[datos.length + 2];
        parametros[0] = actor; parametros[1] = id;
        System.arraycopy(datos, 0, parametros, 2, datos.length);
        return ordenes.una(jdbc.queryForList(sql, parametros));
    }
    public List<ActividadRealizada> actividades(int actor, int id) {
        OrdenesServicio.idValido(id);
        return jdbc.queryForList("EXEC dbo.spActividadesOrden ?, ?", actor, id).stream()
                .map(r -> new ActividadRealizada(entero(r, "ActividadID"), texto(r, "Nombre"), fecha(r, "Fecha"), texto(r, "Observacion"))).toList();
    }
    public List<RepuestoUsado> repuestos(int actor, int id) {
        OrdenesServicio.idValido(id);
        return jdbc.queryForList("EXEC dbo.spRepuestosOrden ?, ?", actor, id).stream().map(r -> new RepuestoUsado(
                entero(r, "Linea"), entero(r, "RepuestoID"), texto(r, "Codigo"), texto(r, "Nombre"), entero(r, "BodegaID"),
                texto(r, "Bodega"), entero(r, "Cantidad"), decimal(r, "PrecioUnitario"), decimal(r, "Importe"),
                r.get("MovimientoID") instanceof Number n ? n.longValue() : null, fecha(r, "Fecha"))).toList();
    }
    public List<ActividadDisponible> catalogoActividades(int actor, int id) {
        OrdenesServicio.idValido(id);
        return jdbc.queryForList("EXEC dbo.spCatalogoActividadesOrden ?, ?", actor, id).stream()
                .map(r -> new ActividadDisponible(entero(r, "ActividadID"), texto(r, "Nombre"))).toList();
    }
    public List<RepuestoDisponible> catalogoRepuestos(int actor, int id) {
        OrdenesServicio.idValido(id);
        return jdbc.queryForList("EXEC dbo.spCatalogoRepuestosOrden ?, ?", actor, id).stream().map(r -> new RepuestoDisponible(
                entero(r, "BodegaID"), texto(r, "Bodega"), entero(r, "RepuestoID"), texto(r, "Codigo"), texto(r, "Nombre"),
                ((Number) r.get("Existencia")).longValue(), decimal(r, "PrecioUnitario"))).toList();
    }
    private static Integer entero(Map<String, Object> r, String clave) { return r.get(clave) instanceof Number n ? n.intValue() : null; }
    private static String texto(Map<String, Object> r, String clave) { return r.get(clave) instanceof String s ? s : null; }
    private static BigDecimal decimal(Map<String, Object> r, String clave) { return r.get(clave) instanceof Number n ? new BigDecimal(n.toString()) : null; }
    private static OffsetDateTime fecha(Map<String, Object> r, String clave) {
        Object valor = r.get(clave);
        if (valor instanceof Timestamp t) return t.toLocalDateTime().atOffset(ZoneOffset.UTC);
        if (valor instanceof LocalDateTime t) return t.atOffset(ZoneOffset.UTC);
        return null;
    }
    public record ActividadDisponible(Integer actividadId, String nombre) {}
    public record ActividadRealizada(Integer actividadId, String nombre, OffsetDateTime fecha, String observacion) {}
    public record RepuestoDisponible(Integer bodegaId, String bodega, Integer repuestoId, String codigo,
                                    String nombre, long existencia, BigDecimal precioUnitario) {}
    public record RepuestoUsado(Integer linea, Integer repuestoId, String codigo, String nombre, Integer bodegaId,
                               String bodega, Integer cantidad, BigDecimal precioUnitario, BigDecimal importe,
                               Long movimientoId, OffsetDateTime fecha) {}
}
