package com.techcare.backend.abastecimiento;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api")
public class AbastecimientoController {
    private final AbastecimientoServicio servicio;
    public AbastecimientoController(AbastecimientoServicio servicio) { this.servicio=servicio; }
    @GetMapping("/repuestos/categorias")
    public List<AbastecimientoServicio.Categoria> categorias(@AuthenticationPrincipal UsuarioAutenticado actor) { return servicio.categorias(actor.getUsuarioId()); }
    @PostMapping("/repuestos/categorias")
    public ResponseEntity<AbastecimientoServicio.Categoria> crearCategoria(@AuthenticationPrincipal UsuarioAutenticado actor,@Valid @RequestBody CategoriaDatos d) {
        var c=servicio.guardarCategoria(actor.getUsuarioId(),null,d);return ResponseEntity.created(URI.create("/api/repuestos/categorias")).body(c);
    }
    @PutMapping("/repuestos/categorias/{id}")
    public AbastecimientoServicio.Categoria editarCategoria(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@Valid @RequestBody CategoriaDatos d) { return servicio.guardarCategoria(actor.getUsuarioId(),id,d); }
    @GetMapping("/repuestos")
    public List<AbastecimientoServicio.Repuesto> repuestos(@AuthenticationPrincipal UsuarioAutenticado actor,@RequestParam(required=false) String buscar,
            @RequestParam(required=false) Integer categoriaId,@RequestParam(required=false) Boolean activo) { return servicio.repuestos(actor.getUsuarioId(),buscar,categoriaId,activo); }
    @GetMapping("/repuestos/{id}")
    public AbastecimientoServicio.Repuesto repuesto(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) { return servicio.repuesto(actor.getUsuarioId(),id); }
    @PostMapping("/repuestos")
    public ResponseEntity<AbastecimientoServicio.Repuesto> crearRepuesto(@AuthenticationPrincipal UsuarioAutenticado actor,@Valid @RequestBody RepuestoDatos d) {
        var r=servicio.guardarRepuesto(actor.getUsuarioId(),null,d);return ResponseEntity.created(URI.create("/api/repuestos/"+r.repuestoId())).body(r);
    }
    @PutMapping("/repuestos/{id}")
    public AbastecimientoServicio.Repuesto editarRepuesto(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@Valid @RequestBody RepuestoDatos d) { return servicio.guardarRepuesto(actor.getUsuarioId(),id,d); }
    @GetMapping("/repuestos/{id}/precios")
    public List<AbastecimientoServicio.Precio> precios(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) { return servicio.precios(actor.getUsuarioId(),id); }
    @GetMapping("/proveedores")
    public List<AbastecimientoServicio.Proveedor> proveedores(@AuthenticationPrincipal UsuarioAutenticado actor,@RequestParam(required=false) String buscar,@RequestParam(required=false) Boolean activo) { return servicio.proveedores(actor.getUsuarioId(),buscar,activo); }
    @GetMapping("/proveedores/{id}")
    public AbastecimientoServicio.Proveedor proveedor(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) { return servicio.proveedor(actor.getUsuarioId(),id); }
    @PostMapping("/proveedores")
    public ResponseEntity<AbastecimientoServicio.Proveedor> crearProveedor(@AuthenticationPrincipal UsuarioAutenticado actor,@Valid @RequestBody ProveedorDatos d) {
        var p=servicio.guardarProveedor(actor.getUsuarioId(),null,d);return ResponseEntity.created(URI.create("/api/proveedores/"+p.proveedorId())).body(p);
    }
    @PutMapping("/proveedores/{id}")
    public AbastecimientoServicio.Proveedor editarProveedor(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@Valid @RequestBody ProveedorDatos d) { return servicio.guardarProveedor(actor.getUsuarioId(),id,d); }
    @GetMapping("/proveedores/{id}/repuestos")
    public List<AbastecimientoServicio.Oferta> ofertas(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) { return servicio.ofertas(actor.getUsuarioId(),id); }
    @PutMapping("/proveedores/{id}/repuestos/{repuestoId}")
    public AbastecimientoServicio.Oferta oferta(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@PathVariable int repuestoId,@Valid @RequestBody OfertaDatos d) { return servicio.guardarOferta(actor.getUsuarioId(),id,repuestoId,d); }
    @GetMapping("/bodegas")
    public List<AbastecimientoServicio.Bodega> bodegas(@AuthenticationPrincipal UsuarioAutenticado actor,@RequestParam(required=false) String buscar,@RequestParam(required=false) Boolean activo) { return servicio.bodegas(actor.getUsuarioId(),buscar,activo); }
    @GetMapping("/bodegas/{id}")
    public AbastecimientoServicio.Bodega bodega(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) { return servicio.bodega(actor.getUsuarioId(),id); }
    @PostMapping("/bodegas")
    public ResponseEntity<AbastecimientoServicio.Bodega> crearBodega(@AuthenticationPrincipal UsuarioAutenticado actor,@Valid @RequestBody BodegaDatos d) {
        var b=servicio.guardarBodega(actor.getUsuarioId(),null,d);return ResponseEntity.created(URI.create("/api/bodegas/"+b.bodegaId())).body(b);
    }
    @PutMapping("/bodegas/{id}")
    public AbastecimientoServicio.Bodega editarBodega(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@Valid @RequestBody BodegaDatos d) { return servicio.guardarBodega(actor.getUsuarioId(),id,d); }
    @GetMapping("/bodegas/{id}/repuestos")
    public List<AbastecimientoServicio.RepuestoBodega> repuestosBodega(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) { return servicio.repuestosBodega(actor.getUsuarioId(),id); }
    @PutMapping("/bodegas/{id}/repuestos/{repuestoId}")
    public AbastecimientoServicio.RepuestoBodega minimo(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@PathVariable int repuestoId,@Valid @RequestBody MinimoDatos d) { return servicio.guardarRepuestoBodega(actor.getUsuarioId(),id,repuestoId,d); }

    public record CategoriaDatos(@NotBlank @Size(max=80) String nombre,@Pattern(regexp="[A-F0-9]{64}") String revision) {
        public CategoriaDatos { nombre=limpiar(nombre); }
    }
    public record RepuestoDatos(
            @NotNull @DecimalMin("1") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal categoriaId,
            @NotBlank @Size(max=30) @Pattern(regexp="[0-9A-Za-z._/\\-]+") String codigo,
            @NotBlank @Size(max=100) String nombre,@Size(max=500) String descripcion,
            @NotNull @DecimalMin("0") @Digits(integer=10,fraction=2) BigDecimal costoReferencia,
            @NotNull @DecimalMin("0") @Digits(integer=10,fraction=2) BigDecimal precioVenta,
            @NotNull Boolean activo,@Pattern(regexp="[A-F0-9]{64}") String revision) {
        public RepuestoDatos { codigo=limpiar(codigo);nombre=limpiar(nombre);descripcion=limpiar(descripcion); }
    }
    public record ProveedorDatos(@NotBlank @Size(max=20) @Pattern(regexp="[0-9A-Za-z\\-]+") String nit,
            @NotBlank @Size(max=150) String nombre,@Email @Size(max=254) String email,
            @Size(max=25) @Pattern(regexp="[ -~]*") String telefono,@Size(max=250) String direccion,
            @NotNull Boolean activo,@Pattern(regexp="[A-F0-9]{64}") String revision) {
        public ProveedorDatos { nit=limpiar(nit);nombre=limpiar(nombre);email=limpiar(email);telefono=limpiar(telefono);direccion=limpiar(direccion); }
    }
    public record BodegaDatos(@NotBlank @Size(max=20) @Pattern(regexp="[0-9A-Za-z._/\\-]+") String codigo,
            @NotBlank @Size(max=100) String nombre,@Size(max=250) String direccion,
            @NotNull Boolean activo,@Pattern(regexp="[A-F0-9]{64}") String revision) {
        public BodegaDatos { codigo=limpiar(codigo);nombre=limpiar(nombre);direccion=limpiar(direccion); }
    }
    public record OfertaDatos(@Size(max=50) @Pattern(regexp="[0-9A-Za-z._/ \\-]*") String codigoProveedor,
            @NotNull Boolean ofrecido,@Pattern(regexp="[A-F0-9]{64}") String revision) {
        public OfertaDatos { codigoProveedor=limpiar(codigoProveedor); }
    }
    public record MinimoDatos(@NotNull @DecimalMin("0") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal stockMinimo,
            @DecimalMin("0") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal stockMinimoEsperado) {}
    private static String limpiar(String v) { return v==null||v.isBlank()?null:v.strip(); }
}
