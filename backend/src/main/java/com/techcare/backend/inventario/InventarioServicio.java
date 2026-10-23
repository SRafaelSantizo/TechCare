package com.techcare.backend.inventario;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.*;
import java.util.List;
import java.util.Map;

@Service
public class InventarioServicio {
    private final JdbcTemplate jdbc;
    public InventarioServicio(JdbcTemplate jdbc) { this.jdbc=jdbc; }

    @Transactional(readOnly=true,isolation=Isolation.SERIALIZABLE)
    public Inventario listar(int actor,String buscar,Integer bodega,Integer categoria,String estado,Boolean activo,int pagina,int tamano) {
        if(buscar!=null&&buscar.length()>150)mal("La búsqueda admite hasta 150 caracteres.");
        idOpcional(bodega);idOpcional(categoria);paginacion(pagina,tamano);
        if(estado!=null&&!List.of("","SIN_EXISTENCIA","BAJO","DISPONIBLE").contains(estado))mal("El estado de stock no es válido.");
        var r=primera(jdbc.queryForList("EXEC dbo.spResumenInventarioApi ?, ?, ?, ?, ?, ?",actor,buscar,bodega,categoria,estado,activo));
        long total=numero(r,"Total"),paginas=paginas(total,tamano);int actual=(int)Math.min(pagina,paginas);
        var filas=jdbc.queryForList("EXEC dbo.spListarInventarioApi ?, ?, ?, ?, ?, ?, ?, ?",actor,buscar,bodega,categoria,estado,activo,actual,tamano)
            .stream().map(InventarioServicio::existencia).toList();
        return new Inventario(filas,new ResumenInventario(total,numero(r,"SinExistencia"),numero(r,"StockBajo"),decimal(r,"ValorTotal")),actual,tamano,total,paginas);
    }

    @Transactional(readOnly=true,isolation=Isolation.SERIALIZABLE)
    public Kardex kardex(int actor,int bodega,int repuesto,LocalDate desde,LocalDate hasta,String tipo,int pagina,int tamano) {
        id(bodega);id(repuesto);paginacion(pagina,tamano);
        if(desde!=null&&hasta!=null&&desde.isAfter(hasta))mal("La fecha inicial no puede ser posterior a la final.");
        if((desde!=null&&(desde.getYear()<1||desde.getYear()>9999))||(hasta!=null&&(hasta.getYear()<1||hasta.getYear()>9999)))mal("La fecha debe estar entre los años 1 y 9999.");
        if(tipo!=null&&!List.of("","E","S").contains(tipo))mal("El tipo de movimiento no es válido.");
        var cabecera=existencia(primera(jdbc.queryForList("EXEC dbo.spConsultarInventarioApi ?, ?, ?",actor,bodega,repuesto)));
        var r=primera(jdbc.queryForList("EXEC dbo.spResumenKardexApi ?, ?, ?, ?, ?, ?",actor,bodega,repuesto,desde,hasta,tipo));
        long total=numero(r,"Total"),paginas=paginas(total,tamano);int actual=(int)Math.min(pagina,paginas);
        var filas=jdbc.queryForList("EXEC dbo.spListarKardexApi ?, ?, ?, ?, ?, ?, ?, ?",actor,bodega,repuesto,desde,hasta,tipo,actual,tamano)
            .stream().map(InventarioServicio::movimiento).toList();
        return new Kardex(cabecera,new ResumenKardex(texto(r,"SaldoInicial"),texto(r,"Entradas"),texto(r,"Salidas"),texto(r,"SaldoFinal")),filas,actual,tamano,total,paginas);
    }

    private static Existencia existencia(Map<String,Object> r) {
        return new Existencia(entero(r,"BodegaID"),texto(r,"CodigoBodega"),texto(r,"Bodega"),bit(r,"BodegaActiva"),
            entero(r,"RepuestoID"),texto(r,"Codigo"),texto(r,"Repuesto"),bit(r,"RepuestoActivo"),entero(r,"CategoriaID"),texto(r,"Categoria"),
            texto(r,"Existencia"),entero(r,"StockMinimo"),texto(r,"Faltante"),texto(r,"EstadoStock"),decimal(r,"CostoPromedio"),decimal(r,"ValorExistencia"));
    }
    private static Movimiento movimiento(Map<String,Object> r) {
        return new Movimiento(texto(r,"MovimientoID"),fecha(r,"Fecha"),texto(r,"Tipo"),entero(r,"Cantidad"),texto(r,"ExistenciaAnterior"),texto(r,"ExistenciaResultante"),
            decimal(r,"CostoUnitario"),decimal(r,"Importe"),decimal(r,"CostoAnterior"),decimal(r,"CostoPosterior"),decimal(r,"ValorExistencia"),
            r.get("EsMigracion")==null?null:bit(r,"EsMigracion"),entero(r,"CompraID"),entero(r,"LineaCompra"),texto(r,"NumeroCompra"),entero(r,"ProveedorID"),texto(r,"Proveedor"),
            entero(r,"OrdenID"),texto(r,"NumeroOrden"),entero(r,"ReparacionID"),entero(r,"LineaReparacion"),entero(r,"UsuarioID"),texto(r,"Responsable"),bit(r,"NombreHistorico"));
    }
    private static long paginas(long total,int tamano) { return Math.max(1,(total-1)/tamano+1); }
    private static void paginacion(int pagina,int tamano) { if(pagina<=0||tamano<1||tamano>100)mal("La página debe ser positiva y el tamaño debe estar entre 1 y 100."); }
    private static void idOpcional(Integer v) { if(v!=null)id(v); }
    private static void id(int v) { if(v<=0)mal("El identificador debe ser positivo."); }
    private static void mal(String mensaje) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,mensaje); }
    private static Map<String,Object> primera(List<Map<String,Object>> filas) {
        if(filas.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"El repuesto no está asociado a esa bodega.");return filas.get(0);
    }
    private static String texto(Map<String,Object> r,String k) { return r.get(k)==null?null:r.get(k).toString(); }
    private static Integer entero(Map<String,Object> r,String k) { return r.get(k) instanceof Number n?n.intValue():null; }
    private static long numero(Map<String,Object> r,String k) { return r.get(k) instanceof Number n?n.longValue():0; }
    private static boolean bit(Map<String,Object> r,String k) { return Boolean.TRUE.equals(r.get(k))||r.get(k) instanceof Number n&&n.intValue()!=0; }
    private static String decimal(Map<String,Object> r,String k) { return r.get(k) instanceof BigDecimal d?d.toPlainString():texto(r,k); }
    private static OffsetDateTime fecha(Map<String,Object> r,String k) {
        var v=r.get(k);if(v instanceof Timestamp t)return t.toLocalDateTime().atOffset(ZoneOffset.UTC);
        if(v instanceof LocalDateTime t)return t.atOffset(ZoneOffset.UTC);return v instanceof OffsetDateTime t?t:null;
    }
    // Importes, saldos y MovimientoID se envían como texto para conservar toda su precisión.
    public record Existencia(Integer bodegaId,String codigoBodega,String bodega,boolean bodegaActiva,Integer repuestoId,String codigo,String repuesto,
        boolean repuestoActivo,Integer categoriaId,String categoria,String existencia,Integer stockMinimo,String faltante,String estadoStock,String costoPromedio,String valorExistencia) {}
    public record ResumenInventario(long total,long sinExistencia,long stockBajo,String valorTotal) {}
    public record Inventario(List<Existencia> filas,ResumenInventario resumen,int pagina,int tamano,long total,long totalPaginas) {}
    public record ResumenKardex(String saldoInicial,String entradas,String salidas,String saldoFinal) {}
    public record Movimiento(String movimientoId,OffsetDateTime fecha,String tipo,Integer cantidad,String existenciaAnterior,String existenciaResultante,
        String costoUnitario,String importe,String costoAnterior,String costoPosterior,String valorExistencia,Boolean esMigracion,Integer compraId,Integer lineaCompra,
        String numeroCompra,Integer proveedorId,String proveedor,Integer ordenId,String numeroOrden,Integer reparacionId,Integer lineaReparacion,Integer usuarioId,String responsable,boolean nombreHistorico) {}
    public record Kardex(Existencia inventario,ResumenKardex resumen,List<Movimiento> filas,int pagina,int tamano,long total,long totalPaginas) {}
}
