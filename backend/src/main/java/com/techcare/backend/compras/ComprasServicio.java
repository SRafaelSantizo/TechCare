package com.techcare.backend.compras;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class ComprasServicio {
    private final JdbcTemplate jdbc;
    public ComprasServicio(JdbcTemplate jdbc) { this.jdbc=jdbc; }
    public List<Compra> listar(int actor,String buscar,String estado,Integer proveedor,LocalDate desde,LocalDate hasta) {
        if(buscar!=null&&buscar.length()>150)mal("La búsqueda admite hasta 150 caracteres.");
        if(estado!=null&&!estado.isEmpty()&&!List.of("PENDIENTE","RECIBIDA","ANULADA").contains(estado))mal("El estado de compra no es válido.");
        if(proveedor!=null)id(proveedor);
        if(desde!=null&&hasta!=null&&desde.isAfter(hasta))mal("La fecha inicial no puede ser posterior a la final.");
        return jdbc.queryForList("EXEC dbo.spListarComprasApi ?, ?, ?, ?, ?, ?",actor,buscar,estado,proveedor,desde,hasta).stream().map(ComprasServicio::compra).toList();
    }
    @Transactional(readOnly=true,isolation=Isolation.SERIALIZABLE)
    public Documento documento(int actor,int compraId) {
        id(compraId);
        var cabecera=primera(jdbc.queryForList("EXEC dbo.spConsultarCompraApi ?, ?",actor,compraId));
        var lineas=jdbc.queryForList("EXEC dbo.spDetalleCompraApi ?, ?",actor,compraId).stream().map(r->new Detalle(
            entero(r,"Linea"),entero(r,"BodegaID"),texto(r,"Bodega"),entero(r,"RepuestoID"),texto(r,"Codigo"),texto(r,"Repuesto"),entero(r,"Cantidad"),
            importe(r,"CostoUnitario"),importe(r,"Importe"),largo(r,"Existencia"),importe(r,"CostoPromedio"),largo(r,"MovimientoID"),
            largo(r,"ExistenciaResultante"),importe(r,"CostoAnterior"),importe(r,"CostoPosterior"),texto(r,"RecibidaPor"))).toList();
        var eventos=jdbc.queryForList("EXEC dbo.spEventosCompraApi ?, ?",actor,compraId).stream().map(r->new Evento(
            texto(r,"Tipo"),texto(r,"Responsable"),fecha(r,"Fecha"),texto(r,"Observacion"))).toList();
        return new Documento(cabecera,lineas,eventos);
    }
    public List<Destino> destinos(int actor,int proveedor) {
        id(proveedor);return jdbc.queryForList("EXEC dbo.spDestinosCompraApi ?, ?",actor,proveedor).stream().map(r->new Destino(
            entero(r,"RepuestoID"),texto(r,"Codigo"),texto(r,"Repuesto"),entero(r,"BodegaID"),texto(r,"Bodega"),texto(r,"CodigoProveedor"),
            largo(r,"Existencia"),entero(r,"StockMinimo"),importe(r,"CostoPromedio"))).toList();
    }
    public List<CostoBodega> costos(int actor,int repuesto) {
        id(repuesto);return jdbc.queryForList("EXEC dbo.spCostosRepuestoApi ?, ?",actor,repuesto).stream().map(r->new CostoBodega(
            entero(r,"BodegaID"),texto(r,"Codigo"),texto(r,"Bodega"),Boolean.TRUE.equals(r.get("Activo"))||r.get("Activo") instanceof Number n&&n.intValue()!=0,
            largo(r,"Existencia"),entero(r,"StockMinimo"),importe(r,"CostoPromedio"))).toList();
    }
    public Compra registrar(int actor,ComprasController.Registro d) {
        var pares=new HashSet<String>();
        for(var linea:d.detalle())if(!pares.add(linea.bodegaId().intValueExact()+":"+linea.repuestoId().intValueExact()))mal("No repitás el mismo repuesto y bodega en dos líneas.");
        // Sólo números ya validados forman este JSON; ningún texto del usuario se concatena en SQL.
        String detalle=d.detalle().stream().map(l->"{\"bodegaId\":"+l.bodegaId().intValueExact()+",\"repuestoId\":"+l.repuestoId().intValueExact()
            +",\"cantidad\":"+l.cantidad().intValueExact()+",\"costoUnitario\":"+l.costoUnitario().stripTrailingZeros().toPlainString()+"}").collect(Collectors.joining(",","[","]"));
        return primera(jdbc.queryForList("EXEC dbo.spRegistrarCompraApi ?, ?, ?, ?, ?, ?",actor,d.solicitudId().toString(),d.numeroCompra(),d.proveedorId().intValueExact(),d.observaciones(),detalle));
    }
    public Compra recibir(int actor,int compraId,String revision) { id(compraId);return primera(jdbc.queryForList("EXEC dbo.spRecibirCompraApi ?, ?, ?",actor,compraId,revision)); }
    public Compra anular(int actor,int compraId,String revision,String motivo) { id(compraId);return primera(jdbc.queryForList("EXEC dbo.spAnularCompraApi ?, ?, ?, ?",actor,compraId,revision,motivo)); }
    private static void id(int id) { if(id<=0)mal("El identificador debe ser positivo."); }
    private static void mal(String mensaje) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,mensaje); }
    private static Compra primera(List<Map<String,Object>> filas) {
        if(filas.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"La compra no existe.");return compra(filas.get(0));
    }
    private static Compra compra(Map<String,Object> r) { return new Compra(entero(r,"CompraID"),texto(r,"NumeroCompra"),entero(r,"ProveedorID"),texto(r,"NIT"),texto(r,"Proveedor"),
        fecha(r,"Fecha"),texto(r,"Estado"),fecha(r,"FechaRecepcion"),texto(r,"Observaciones"),texto(r,"RegistradaPor"),texto(r,"RecibidaPor"),texto(r,"AnuladaPor"),
        fecha(r,"FechaAnulacion"),texto(r,"MotivoAnulacion"),entero(r,"Lineas"),importe(r,"Total"),texto(r,"Revision")); }
    private static String texto(Map<String,Object> r,String k) { return r.get(k)==null?null:r.get(k).toString(); }
    private static Integer entero(Map<String,Object> r,String k) { return r.get(k) instanceof Number n?n.intValue():null; }
    private static Long largo(Map<String,Object> r,String k) { return r.get(k) instanceof Number n?n.longValue():null; }
    private static String importe(Map<String,Object> r,String k) { return r.get(k) instanceof BigDecimal n?n.toPlainString():texto(r,k); }
    private static OffsetDateTime fecha(Map<String,Object> r,String k) {
        var v=r.get(k);if(v instanceof Timestamp t)return t.toLocalDateTime().atOffset(ZoneOffset.UTC);
        if(v instanceof LocalDateTime t)return t.atOffset(ZoneOffset.UTC);return v instanceof OffsetDateTime t?t:null;
    }
    // Los importes se envían como texto decimal para no perder centavos en JavaScript.
    public record Compra(Integer compraId,String numeroCompra,Integer proveedorId,String nit,String proveedor,OffsetDateTime fecha,String estado,
        OffsetDateTime fechaRecepcion,String observaciones,String registradaPor,String recibidaPor,String anuladaPor,OffsetDateTime fechaAnulacion,
        String motivoAnulacion,Integer lineas,String total,String revision) {}
    public record Detalle(Integer linea,Integer bodegaId,String bodega,Integer repuestoId,String codigo,String repuesto,Integer cantidad,String costoUnitario,
        String importe,Long existencia,String costoPromedio,Long movimientoId,Long existenciaResultante,String costoAnterior,String costoPosterior,String recibidaPor) {}
    public record Evento(String tipo,String responsable,OffsetDateTime fecha,String observacion) {}
    public record Documento(Compra compra,List<Detalle> detalle,List<Evento> eventos) {}
    public record Destino(Integer repuestoId,String codigo,String repuesto,Integer bodegaId,String bodega,String codigoProveedor,Long existencia,Integer stockMinimo,String costoPromedio) {}
    public record CostoBodega(Integer bodegaId,String codigo,String bodega,boolean activo,Long existencia,Integer stockMinimo,String costoPromedio) {}
}
