package com.techcare.backend.ordenes;

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
@RequestMapping("/api/ordenes/{id}")
public class ServicioTecnicoController {
    private final ServicioTecnico servicio;
    public ServicioTecnicoController(ServicioTecnico servicio) { this.servicio = servicio; }

    @PostMapping("/diagnostico/inicio")
    public OrdenesServicio.Orden iniciarDiagnostico(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return servicio.iniciarDiagnostico(actor.getUsuarioId(), id);
    }

    @PostMapping("/diagnostico")
    public ResponseEntity<OrdenesServicio.Orden> diagnosticar(@AuthenticationPrincipal UsuarioAutenticado actor,
            @PathVariable int id, @Valid @RequestBody Diagnostico datos) {
        return ResponseEntity.created(URI.create("/api/ordenes/" + id))
                .body(servicio.diagnosticar(actor.getUsuarioId(), id, datos));
    }

    @PostMapping("/reparacion")
    public ResponseEntity<OrdenesServicio.Orden> reparar(@AuthenticationPrincipal UsuarioAutenticado actor,
            @PathVariable int id, @Valid @RequestBody Reparacion datos) {
        return ResponseEntity.created(URI.create("/api/ordenes/" + id))
                .body(servicio.reparar(actor.getUsuarioId(), id, datos));
    }

    @GetMapping("/actividades")
    public List<ServicioTecnico.ActividadRealizada> actividades(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return servicio.actividades(actor.getUsuarioId(), id);
    }

    @PostMapping("/actividades")
    public OrdenesServicio.Orden actividad(@AuthenticationPrincipal UsuarioAutenticado actor,
            @PathVariable int id, @Valid @RequestBody Actividad datos) {
        return servicio.agregarActividad(actor.getUsuarioId(), id, datos);
    }

    @GetMapping("/repuestos")
    public List<ServicioTecnico.RepuestoUsado> repuestos(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return servicio.repuestos(actor.getUsuarioId(), id);
    }

    @PostMapping("/repuestos")
    public OrdenesServicio.Orden repuesto(@AuthenticationPrincipal UsuarioAutenticado actor,
            @PathVariable int id, @Valid @RequestBody Consumo datos) {
        return servicio.consumir(actor.getUsuarioId(), id, datos);
    }

    @GetMapping("/catalogos/actividades")
    public List<ServicioTecnico.ActividadDisponible> catalogoActividades(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return servicio.catalogoActividades(actor.getUsuarioId(), id);
    }

    @GetMapping("/catalogos/repuestos")
    public List<ServicioTecnico.RepuestoDisponible> catalogoRepuestos(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return servicio.catalogoRepuestos(actor.getUsuarioId(), id);
    }

    @PostMapping("/reparacion/cierre")
    public OrdenesServicio.Orden finalizar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return servicio.finalizar(actor.getUsuarioId(), id);
    }

    public record Diagnostico(
            @NotBlank @Size(max = 2000) String descripcion,
            @NotNull @DecimalMin("0.00") @Digits(integer = 10, fraction = 2) BigDecimal costoEstimado) {
        public Diagnostico { descripcion = limpiar(descripcion); }
    }
    public record Reparacion(
            @NotBlank @Size(max = 2000) String descripcionTrabajo,
            @NotNull @DecimalMin("0.00") @Digits(integer = 10, fraction = 2) BigDecimal costoManoObra,
            @NotBlank @Size(max = 500) String autorizacion) {
        public Reparacion { descripcionTrabajo = limpiar(descripcionTrabajo); autorizacion = limpiar(autorizacion); }
    }
    public record Actividad(@NotNull @Min(1) Integer actividadId, @Size(max = 500) String observacion) {
        public Actividad { observacion = limpiar(observacion); }
    }
    public record Consumo(
            @NotNull @Min(1) Integer bodegaId, @NotNull @Min(1) Integer repuestoId,
            // BigDecimal conserva una fracción recibida para rechazarla; Integer la truncaría al leer JSON.
            @NotNull @DecimalMin("1") @DecimalMax("2147483647") @Digits(integer = 10, fraction = 0) BigDecimal cantidad,
            @NotNull @DecimalMin("0.00") @Digits(integer = 10, fraction = 2) BigDecimal precioUnitarioEsperado) {}
    private static String limpiar(String texto) { return texto == null ? null : texto.strip(); }
}
