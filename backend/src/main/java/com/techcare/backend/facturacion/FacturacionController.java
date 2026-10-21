package com.techcare.backend.facturacion;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class FacturacionController {
    private final FacturacionServicio servicio;
    private final FacturaPdf pdf;
    public FacturacionController(FacturacionServicio servicio, FacturaPdf pdf) { this.servicio = servicio; this.pdf = pdf; }

    @GetMapping("/facturas")
    public List<FacturacionServicio.FilaCaja> listar(@AuthenticationPrincipal UsuarioAutenticado actor,
            @RequestParam(required=false) String buscar, @RequestParam(required=false) String estadoPago) {
        return servicio.listar(actor.getUsuarioId(), buscar, estadoPago);
    }
    @GetMapping("/caja/metodos-pago")
    public List<FacturacionServicio.Metodo> metodos(@AuthenticationPrincipal UsuarioAutenticado actor) { return servicio.metodos(actor.getUsuarioId()); }
    @GetMapping("/ordenes/{id}/factura")
    public FacturacionServicio.Factura consultar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) { return servicio.consultar(actor.getUsuarioId(),id); }
    @GetMapping("/ordenes/{id}/factura/previa")
    public FacturacionServicio.Previa previa(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id,
            @RequestParam(defaultValue="0.1200") BigDecimal tasaImpuesto) { return servicio.previa(actor.getUsuarioId(),id,tasaImpuesto); }
    @PostMapping("/ordenes/{id}/factura")
    public ResponseEntity<FacturacionServicio.Factura> emitir(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id,
            @Valid @RequestBody Emision datos) {
        return ResponseEntity.created(URI.create("/api/ordenes/"+id+"/factura")).body(servicio.emitir(actor.getUsuarioId(),id,datos));
    }
    @GetMapping("/ordenes/{id}/factura/detalles")
    public List<FacturacionServicio.Detalle> detalles(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) { return servicio.detalles(actor.getUsuarioId(),id); }
    @GetMapping("/ordenes/{id}/factura/pagos")
    public List<FacturacionServicio.Pago> pagos(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) { return servicio.pagos(actor.getUsuarioId(),id); }
    @PostMapping("/ordenes/{id}/factura/pagos")
    public FacturacionServicio.Factura abonar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id,
            @Valid @RequestBody Abono datos) { return servicio.abonar(actor.getUsuarioId(),id,datos); }
    @GetMapping(value="/ordenes/{id}/factura/pdf", produces=MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> descargar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        var documento = servicio.documento(actor.getUsuarioId(),id);
        // El nombre no admite rutas, saltos de línea ni texto ingresado en la solicitud.
        String numero = documento.factura().numeroFactura().replaceAll("[^A-Za-z0-9_-]", "_");
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_PDF)
                .cacheControl(CacheControl.noStore())
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename("Factura-"+numero+".pdf", StandardCharsets.UTF_8).build().toString())
                .body(pdf.generar(documento));
    }
    @GetMapping("/ordenes/{id}/entrega")
    public FacturacionServicio.Entrega entrega(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) { return servicio.entrega(actor.getUsuarioId(),id); }
    @PostMapping("/ordenes/{id}/entrega")
    public FacturacionServicio.Entrega entregar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id,
            @Valid @RequestBody Recepcion datos) { return servicio.entregar(actor.getUsuarioId(),id,datos); }

    public record Emision(@NotNull @DecimalMin("0") @DecimalMax("1") @Digits(integer=1,fraction=4) BigDecimal tasaImpuesto,
            @NotBlank @Pattern(regexp="[A-Fa-f0-9]{64}") String revision) {}
    public record Abono(@NotNull UUID solicitudId,
            @NotNull @DecimalMin("1") @DecimalMax("255") @Digits(integer=3,fraction=0) BigDecimal metodoPagoId,
            @NotNull @DecimalMin("0.01") @Digits(integer=10,fraction=2) BigDecimal monto,
            @NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal saldoEsperado,
            @Size(max=100) String referencia) {
        public Abono { referencia = limpiar(referencia); }
    }
    public record Recepcion(@NotBlank @Size(max=150) String nombreRecibe,
            @Size(max=30) @Pattern(regexp="[0-9A-Za-z -]*") String documentoRecibe,
            @Size(max=1000) String observaciones) {
        public Recepcion { nombreRecibe=limpiar(nombreRecibe); documentoRecibe=limpiar(documentoRecibe); observaciones=limpiar(observaciones); }
    }
    private static String limpiar(String v) { return v == null || v.isBlank() ? null : v.strip(); }
}
