package com.techcare.backend.abastecimiento;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

@Service
public class AbastecimientoServicio {
    private final JdbcTemplate jdbc;
    public AbastecimientoServicio(JdbcTemplate jdbc) { this.jdbc=jdbc; }
    public List<Categoria> categorias(int actor) {
        return jdbc.queryForList("EXEC dbo.spListarCategoriasRepuesto ?",actor).stream().map(AbastecimientoServicio::categoria).toList();
    }
    public Categoria guardarCategoria(int actor,Integer id,AbastecimientoController.CategoriaDatos d) {
        revision(id,d.revision());
        return una(jdbc.queryForList("EXEC dbo.spGuardarCategoriaRepuesto ?, ?, ?, ?",actor,id,d.nombre(),d.revision()),AbastecimientoServicio::categoria);
    }
    public List<Repuesto> repuestos(int actor,String buscar,Integer categoria,Boolean activo) {
        filtro(buscar); if(categoria!=null) idValido(categoria);
        return jdbc.queryForList("EXEC dbo.spListarRepuestosGestion ?, ?, ?, ?",actor,buscar,categoria,activo).stream().map(AbastecimientoServicio::repuesto).toList();
    }
    public Repuesto repuesto(int actor,int id) {
        idValido(id);return una(jdbc.queryForList("EXEC dbo.spConsultarRepuestoGestion ?, ?",actor,id),AbastecimientoServicio::repuesto);
    }
    public Repuesto guardarRepuesto(int actor,Integer id,AbastecimientoController.RepuestoDatos d) {
        revision(id,d.revision());
        return una(jdbc.queryForList("EXEC dbo.spGuardarRepuestoGestion ?, ?, ?, ?, ?, ?, ?, ?, ?, ?",actor,id,d.categoriaId().intValueExact(),
                d.codigo(),d.nombre(),d.descripcion(),d.costoReferencia(),d.precioVenta(),d.activo(),d.revision()),AbastecimientoServicio::repuesto);
    }
    public List<Precio> precios(int actor,int id) {
        idValido(id);return jdbc.queryForList("EXEC dbo.spPreciosRepuestoGestion ?, ?",actor,id).stream().map(r->new Precio(
                largo(r,"AuditoriaID"),fecha(r,"Fecha"),decimal(r,"CostoAnterior"),decimal(r,"CostoNuevo"),decimal(r,"PrecioAnterior"),decimal(r,"PrecioNuevo"),texto(r,"RegistradoPor"))).toList();
    }
    public List<Proveedor> proveedores(int actor,String buscar,Boolean activo) {
        filtro(buscar);return jdbc.queryForList("EXEC dbo.spListarProveedoresGestion ?, ?, ?",actor,buscar,activo).stream().map(AbastecimientoServicio::proveedor).toList();
    }
    public Proveedor proveedor(int actor,int id) {
        idValido(id);return una(jdbc.queryForList("EXEC dbo.spConsultarProveedorGestion ?, ?",actor,id),AbastecimientoServicio::proveedor);
    }
    public Proveedor guardarProveedor(int actor,Integer id,AbastecimientoController.ProveedorDatos d) {
        revision(id,d.revision());
        return una(jdbc.queryForList("EXEC dbo.spGuardarProveedorGestion ?, ?, ?, ?, ?, ?, ?, ?, ?",actor,id,d.nit(),d.nombre(),d.email(),d.telefono(),d.direccion(),d.activo(),d.revision()),AbastecimientoServicio::proveedor);
    }
    public List<Oferta> ofertas(int actor,int id) {
        idValido(id);return jdbc.queryForList("EXEC dbo.spOfertasProveedorGestion ?, ?",actor,id).stream().map(AbastecimientoServicio::oferta).toList();
    }
    public Oferta guardarOferta(int actor,int id,int repuesto,AbastecimientoController.OfertaDatos d) {
        idValido(id);idValido(repuesto);
        var filas=jdbc.queryForList("EXEC dbo.spGuardarOfertaProveedor ?, ?, ?, ?, ?, ?",actor,id,repuesto,d.codigoProveedor(),d.ofrecido(),d.revision());
        return filas.isEmpty()?null:oferta(filas.get(0));
    }
    public List<Bodega> bodegas(int actor,String buscar,Boolean activo) {
        filtro(buscar);return jdbc.queryForList("EXEC dbo.spListarBodegasGestion ?, ?, ?",actor,buscar,activo).stream().map(AbastecimientoServicio::bodega).toList();
    }
    public Bodega bodega(int actor,int id) {
        idValido(id);return una(jdbc.queryForList("EXEC dbo.spConsultarBodegaGestion ?, ?",actor,id),AbastecimientoServicio::bodega);
    }
    public Bodega guardarBodega(int actor,Integer id,AbastecimientoController.BodegaDatos d) {
        revision(id,d.revision());
        return una(jdbc.queryForList("EXEC dbo.spGuardarBodegaGestion ?, ?, ?, ?, ?, ?, ?",actor,id,d.codigo(),d.nombre(),d.direccion(),d.activo(),d.revision()),AbastecimientoServicio::bodega);
    }
    public List<RepuestoBodega> repuestosBodega(int actor,int id) {
        idValido(id);return jdbc.queryForList("EXEC dbo.spRepuestosBodegaGestion ?, ?",actor,id).stream().map(AbastecimientoServicio::repuestoBodega).toList();
    }
    public RepuestoBodega guardarRepuestoBodega(int actor,int id,int repuesto,AbastecimientoController.MinimoDatos d) {
        idValido(id);idValido(repuesto);
        return una(jdbc.queryForList("EXEC dbo.spGuardarRepuestoBodega ?, ?, ?, ?, ?",actor,id,repuesto,d.stockMinimo(),d.stockMinimoEsperado()),AbastecimientoServicio::repuestoBodega);
    }
    private static <T>T una(List<Map<String,Object>> filas,Function<Map<String,Object>,T> mapper) {
        if(filas.isEmpty())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"El registro no existe.");return mapper.apply(filas.get(0));
    }
    private static void revision(Integer id,String revision) {
        if(id!=null)idValido(id);
        if((id!=null)!=(revision!=null))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Para editar, abrí el registro actualizado; para crear, no envíes una revisión anterior.");
    }
    private static void idValido(int id) { if(id<=0)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"El identificador debe ser positivo."); }
    private static void filtro(String buscar) { if(buscar!=null&&buscar.length()>150)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"La búsqueda admite hasta 150 caracteres."); }
    private static Categoria categoria(Map<String,Object> r) { return new Categoria(entero(r,"CategoriaID"),texto(r,"Nombre"),texto(r,"Revision")); }
    private static Repuesto repuesto(Map<String,Object> r) { return new Repuesto(entero(r,"RepuestoID"),entero(r,"CategoriaID"),texto(r,"Categoria"),texto(r,"Codigo"),texto(r,"Nombre"),texto(r,"Descripcion"),decimal(r,"CostoReferencia"),decimal(r,"PrecioVenta"),activo(r),texto(r,"Revision")); }
    private static Proveedor proveedor(Map<String,Object> r) { return new Proveedor(entero(r,"ProveedorID"),texto(r,"NIT"),texto(r,"Nombre"),texto(r,"Email"),texto(r,"Telefono"),texto(r,"Direccion"),activo(r),texto(r,"Revision")); }
    private static Bodega bodega(Map<String,Object> r) { return new Bodega(entero(r,"BodegaID"),texto(r,"Codigo"),texto(r,"Nombre"),texto(r,"Direccion"),activo(r),texto(r,"Revision")); }
    private static Oferta oferta(Map<String,Object> r) { return new Oferta(entero(r,"ProveedorID"),entero(r,"RepuestoID"),texto(r,"Codigo"),texto(r,"Nombre"),entero(r,"CategoriaID"),texto(r,"Categoria"),activo(r),decimal(r,"PrecioVenta"),texto(r,"CodigoProveedor"),texto(r,"Revision")); }
    private static RepuestoBodega repuestoBodega(Map<String,Object> r) { return new RepuestoBodega(entero(r,"BodegaID"),entero(r,"RepuestoID"),texto(r,"Codigo"),texto(r,"Nombre"),activo(r),entero(r,"StockMinimo"),largo(r,"Existencia")); }
    private static String texto(Map<String,Object> r,String k) { return r.get(k)==null?null:r.get(k).toString(); }
    private static Integer entero(Map<String,Object> r,String k) { return r.get(k) instanceof Number n?n.intValue():null; }
    private static Long largo(Map<String,Object> r,String k) { return r.get(k) instanceof Number n?n.longValue():null; }
    private static BigDecimal decimal(Map<String,Object> r,String k) { return r.get(k) instanceof BigDecimal n?n:r.get(k) instanceof Number n?new BigDecimal(n.toString()):null; }
    private static boolean activo(Map<String,Object> r) { return Boolean.TRUE.equals(r.get("Activo"))||(r.get("Activo") instanceof Number n&&n.intValue()!=0); }
    private static OffsetDateTime fecha(Map<String,Object> r,String k) {
        Object v=r.get(k);if(v instanceof Timestamp t)return t.toLocalDateTime().atOffset(ZoneOffset.UTC);
        if(v instanceof LocalDateTime t)return t.atOffset(ZoneOffset.UTC);return v instanceof OffsetDateTime t?t:null;
    }
    public record Categoria(Integer categoriaId,String nombre,String revision) {}
    public record Repuesto(Integer repuestoId,Integer categoriaId,String categoria,String codigo,String nombre,String descripcion,BigDecimal costoReferencia,BigDecimal precioVenta,boolean activo,String revision) {}
    public record Proveedor(Integer proveedorId,String nit,String nombre,String email,String telefono,String direccion,boolean activo,String revision) {}
    public record Bodega(Integer bodegaId,String codigo,String nombre,String direccion,boolean activo,String revision) {}
    public record Oferta(Integer proveedorId,Integer repuestoId,String codigo,String nombre,Integer categoriaId,String categoria,boolean activo,BigDecimal precioVenta,String codigoProveedor,String revision) {}
    public record RepuestoBodega(Integer bodegaId,Integer repuestoId,String codigo,String nombre,boolean activo,Integer stockMinimo,Long existencia) {}
    public record Precio(Long auditoriaId,OffsetDateTime fecha,BigDecimal costoAnterior,BigDecimal costoNuevo,BigDecimal precioAnterior,BigDecimal precioNuevo,String registradoPor) {}
}
