package com.techcare.backend.compras;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.net.URI;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class ComprasController {
    private final ComprasServicio servicio;
    public ComprasController(ComprasServicio servicio) { this.servicio=servicio; }
    @GetMapping("/compras")
    public List<ComprasServicio.Compra> listar(@AuthenticationPrincipal UsuarioAutenticado actor,
            @RequestParam(required=false) String buscar,@RequestParam(required=false) String estado,
            @RequestParam(required=false) Integer proveedorId,@RequestParam(required=false) LocalDate desde,
            @RequestParam(required=false) LocalDate hasta) {
        return servicio.listar(actor.getUsuarioId(),buscar,estado,proveedorId,desde,hasta);
    }
    @GetMapping("/compras/{id}")
    public ComprasServicio.Documento consultar(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) {
        return servicio.documento(actor.getUsuarioId(),id);
    }
    @GetMapping("/compras/catalogos/destinos")
    public List<ComprasServicio.Destino> destinos(@AuthenticationPrincipal UsuarioAutenticado actor,@RequestParam int proveedorId) {
        return servicio.destinos(actor.getUsuarioId(),proveedorId);
    }
    @GetMapping("/repuestos/{id}/costos")
    public List<ComprasServicio.CostoBodega> costos(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id) {
        return servicio.costos(actor.getUsuarioId(),id);
    }
    @PostMapping("/compras")
    public ResponseEntity<ComprasServicio.Compra> registrar(@AuthenticationPrincipal UsuarioAutenticado actor,@Valid @RequestBody Registro d) {
        var compra=servicio.registrar(actor.getUsuarioId(),d);
        return ResponseEntity.created(URI.create("/api/compras/"+compra.compraId())).body(compra);
    }
    @PostMapping("/compras/{id}/recepcion")
    public ComprasServicio.Compra recibir(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@Valid @RequestBody Confirmacion d) {
        return servicio.recibir(actor.getUsuarioId(),id,d.revision());
    }
    @PostMapping("/compras/{id}/anulacion")
    public ComprasServicio.Compra anular(@AuthenticationPrincipal UsuarioAutenticado actor,@PathVariable int id,@Valid @RequestBody Anulacion d) {
        return servicio.anular(actor.getUsuarioId(),id,d.revision(),d.motivo());
    }
    public record Registro(@NotNull UUID solicitudId,
        @NotBlank @Size(max=30) @Pattern(regexp="[0-9A-Za-z._/\\-]+") String numeroCompra,
        @NotNull @DecimalMin("1") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal proveedorId,
        @Size(max=1000) String observaciones,@NotEmpty @Size(max=200) List<@NotNull @Valid Linea> detalle) {
        public Registro { numeroCompra=limpiar(numeroCompra);observaciones=limpiar(observaciones); }
    }
    public record Linea(
        @NotNull @DecimalMin("1") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal bodegaId,
        @NotNull @DecimalMin("1") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal repuestoId,
        @NotNull @DecimalMin("1") @DecimalMax("2147483647") @Digits(integer=10,fraction=0) BigDecimal cantidad,
        @NotNull @DecimalMin("0") @Digits(integer=10,fraction=2) BigDecimal costoUnitario) {}
    public record Confirmacion(@NotNull @Pattern(regexp="[A-F0-9]{64}") String revision) {}
    public record Anulacion(@NotNull @Pattern(regexp="[A-F0-9]{64}") String revision,@NotBlank @Size(max=1000) String motivo) {
        public Anulacion { motivo=limpiar(motivo); }
    }
    private static String limpiar(String v) { return v==null||v.isBlank()?null:v.strip(); }
}
