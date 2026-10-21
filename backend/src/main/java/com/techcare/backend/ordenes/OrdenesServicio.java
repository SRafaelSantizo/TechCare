package com.techcare.backend.ordenes;

import org.springframework.dao.DataRetrievalFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class OrdenesServicio {
    private static final ZoneId GUATEMALA = ZoneId.of("America/Guatemala");
    private final JdbcTemplate jdbc;
    public OrdenesServicio(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public List<Orden> listar(int actor, String buscar, String estado, String prioridad, Integer tecnico,
                              LocalDate desde, LocalDate hasta) {
        if ((buscar != null && buscar.length() > 150) || (estado != null && estado.length() > 30)
                || (prioridad != null && prioridad.length() > 10) || (tecnico != null && tecnico < 0)
                || (desde != null && hasta != null && desde.isAfter(hasta)))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Revisá los filtros de búsqueda y las fechas.");
        return jdbc.queryForList("EXEC dbo.spListarOrdenes ?, ?, ?, ?, ?, ?, ?",
                actor, buscar, estado, prioridad, tecnico, inicioUtc(desde, false), inicioUtc(hasta, true))
                .stream().map(this::orden).toList();
    }
    public Orden consultar(int actor, int id) {
        idValido(id);
        var filas = jdbc.queryForList("EXEC dbo.spConsultarOrden ?, ?", actor, id);
        if (filas.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "La orden no existe o no está disponible para tu usuario.");
        return una(filas);
    }
    public Orden crear(int actor, OrdenController.NuevaOrden datos) {
        LocalDateTime estimada = datos.fechaEstimada() == null ? null
                : datos.fechaEstimada().withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime();
        if (estimada != null && (estimada.getYear() < 1 || estimada.getYear() > 9999))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La fecha estimada está fuera del rango permitido.");
        return una(jdbc.queryForList("EXEC dbo.spRegistrarOrden ?, ?, ?, ?, ?, ?", actor,
                datos.equipoId(), datos.problema(), datos.prioridad(), estimada, datos.observaciones()));
    }
    public Orden asignar(int actor, int id, OrdenController.AsignarTecnico datos) {
        idValido(id);
        return una(jdbc.queryForList("EXEC dbo.spAsignarTecnicoOrden ?, ?, ?, ?, ?",
                actor, id, datos.tecnicoId(), datos.tecnicoAnteriorId(), datos.observacion()));
    }
    public Orden cancelar(int actor, int id, String motivo) {
        idValido(id);
        return una(jdbc.queryForList("EXEC dbo.spCancelarOrden ?, ?, ?", actor, id, motivo));
    }
    public List<Evento> historial(int actor, int id) {
        idValido(id);
        return jdbc.queryForList("EXEC dbo.spHistorialOrden ?, ?", actor, id).stream().map(r -> new Evento(
                texto(r, "EventoID"), texto(r, "Tipo"), fecha(r, "Fecha"), texto(r, "Usuario"),
                texto(r, "NombreUsuario"), texto(r, "EstadoAnterior"), texto(r, "EstadoNuevo"),
                texto(r, "Tecnico"), texto(r, "Observacion"))).toList();
    }
    public Object catalogo(int actor, String catalogo) {
        if (!Set.of("estados", "prioridades", "tecnicos").contains(catalogo))
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "El catálogo solicitado no existe.");
        List<Map<String, Object>> filas = jdbc.queryForList("EXEC dbo.spCatalogosOrden ?, ?", actor, catalogo);
        if (catalogo.equals("tecnicos")) return filas.stream().map(r -> new Tecnico(
                numero(r, "UsuarioID"), texto(r, "EmpleadoCodigo"), texto(r, "Nombre"))).toList();
        return filas.stream().map(r -> new Catalogo(texto(r, "Codigo"), texto(r, "Nombre"),
                numero(r, "Nivel"), r.get("EsFinal") instanceof Boolean b ? b : null)).toList();
    }
    static void idValido(int id) {
        if (id <= 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El ID de orden debe ser mayor que cero.");
    }
    private static LocalDateTime inicioUtc(LocalDate fecha, boolean diaSiguiente) {
        if (fecha == null) return null;
        if (fecha.getYear() < 1 || fecha.getYear() > 9998)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La fecha del filtro está fuera del rango permitido.");
        return (diaSiguiente ? fecha.plusDays(1) : fecha).atStartOfDay(GUATEMALA)
                .withZoneSameInstant(ZoneOffset.UTC).toLocalDateTime();
    }
    Orden una(List<Map<String, Object>> filas) {
        if (filas.size() != 1 || !(filas.get(0).get("OrdenID") instanceof Number))
            throw new DataRetrievalFailureException("El procedimiento no devolvió una orden válida.");
        return orden(filas.get(0));
    }
    private Orden orden(Map<String, Object> r) {
        if (!(r.get("OrdenID") instanceof Number)) throw new DataRetrievalFailureException("Orden incompleta.");
        // Respuesta explícita: los campos internos de autenticación nunca se serializan.
        return new Orden(numero(r, "OrdenID"), texto(r, "NumeroOrden"), numero(r, "EquipoID"),
                texto(r, "NumeroSerie"), texto(r, "EquipoDescripcion"), texto(r, "Marca"), texto(r, "Modelo"),
                numero(r, "ClienteID"), texto(r, "Cliente"), texto(r, "NIT"), numero(r, "UsuarioRecepcionID"),
                texto(r, "Recepcionista"), fecha(r, "FechaIngreso"), texto(r, "ProblemaReportado"),
                texto(r, "PrioridadCodigo"), texto(r, "Prioridad"), texto(r, "EstadoCodigo"), texto(r, "Estado"),
                Boolean.TRUE.equals(r.get("EsFinal")), fecha(r, "FechaEstimada"), texto(r, "Observaciones"),
                numero(r, "UsuarioTecnicoID"), texto(r, "Tecnico"), numero(r, "DiagnosticoID"),
                fecha(r, "FechaDiagnostico"), texto(r, "DescripcionDiagnostico"), decimal(r, "CostoEstimado"),
                numero(r, "ReparacionID"), fecha(r, "FechaInicioReparacion"), fecha(r, "FechaFinReparacion"),
                texto(r, "DescripcionTrabajo"), decimal(r, "CostoManoObra"), texto(r, "EstadoReparacion"));
    }
    private static Integer numero(Map<String, Object> r, String clave) { return r.get(clave) instanceof Number n ? n.intValue() : null; }
    private static String texto(Map<String, Object> r, String clave) { return r.get(clave) instanceof String s ? s : null; }
    private static BigDecimal decimal(Map<String, Object> r, String clave) {
        return r.get(clave) instanceof Number n ? new BigDecimal(n.toString()) : null;
    }
    private static OffsetDateTime fecha(Map<String, Object> r, String clave) {
        Object valor = r.get(clave);
        if (valor instanceof Timestamp ts) return ts.toLocalDateTime().atOffset(ZoneOffset.UTC);
        if (valor instanceof LocalDateTime fecha) return fecha.atOffset(ZoneOffset.UTC);
        if (valor instanceof OffsetDateTime fecha) return fecha.withOffsetSameInstant(ZoneOffset.UTC);
        return null;
    }
    public record Orden(Integer ordenId, String numeroOrden, Integer equipoId, String numeroSerie,
            String equipoDescripcion, String marca, String modelo, Integer clienteId, String cliente, String nit,
            Integer usuarioRecepcionId, String recepcionista, OffsetDateTime fechaIngreso, String problemaReportado,
            String prioridadCodigo, String prioridad, String estadoCodigo, String estado, boolean esFinal,
            OffsetDateTime fechaEstimada, String observaciones, Integer usuarioTecnicoId, String tecnico,
            Integer diagnosticoId, OffsetDateTime fechaDiagnostico, String descripcionDiagnostico, BigDecimal costoEstimado,
            Integer reparacionId, OffsetDateTime fechaInicioReparacion, OffsetDateTime fechaFinReparacion,
            String descripcionTrabajo, BigDecimal costoManoObra, String estadoReparacion) {}
    public record Evento(String eventoId, String tipo, OffsetDateTime fecha, String usuario, String nombreUsuario,
                         String estadoAnterior, String estadoNuevo, String tecnico, String observacion) {}
    public record Tecnico(Integer usuarioId, String empleadoCodigo, String nombre) {}
    public record Catalogo(String codigo, String nombre, Integer nivel, Boolean esFinal) {}
}
