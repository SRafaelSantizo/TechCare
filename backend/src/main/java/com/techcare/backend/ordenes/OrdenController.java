package com.techcare.backend.ordenes;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/ordenes")
public class OrdenController {
    private final OrdenesServicio ordenes;
    public OrdenController(OrdenesServicio ordenes) { this.ordenes = ordenes; }

    @GetMapping
    public List<OrdenesServicio.Orden> listar(@AuthenticationPrincipal UsuarioAutenticado actor,
            @RequestParam(required = false) String buscar, @RequestParam(required = false) String estado,
            @RequestParam(required = false) String prioridad, @RequestParam(required = false) Integer tecnicoId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        return ordenes.listar(actor.getUsuarioId(), buscar, estado, prioridad, tecnicoId, desde, hasta);
    }

    @GetMapping("/{id}")
    public OrdenesServicio.Orden consultar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return ordenes.consultar(actor.getUsuarioId(), id);
    }

    @GetMapping("/{id}/historial")
    public List<OrdenesServicio.Evento> historial(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id) {
        return ordenes.historial(actor.getUsuarioId(), id);
    }

    @GetMapping("/catalogos/{catalogo}")
    public Object catalogo(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable String catalogo) {
        return ordenes.catalogo(actor.getUsuarioId(), catalogo);
    }

    @PostMapping
    public ResponseEntity<OrdenesServicio.Orden> crear(@AuthenticationPrincipal UsuarioAutenticado actor,
            @Valid @RequestBody NuevaOrden datos) {
        var orden = ordenes.crear(actor.getUsuarioId(), datos);
        return ResponseEntity.created(URI.create("/api/ordenes/" + orden.ordenId())).body(orden);
    }

    @PutMapping("/{id}/tecnico")
    public OrdenesServicio.Orden asignar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id,
            @Valid @RequestBody AsignarTecnico datos) {
        return ordenes.asignar(actor.getUsuarioId(), id, datos);
    }

    @PostMapping("/{id}/cancelacion")
    public OrdenesServicio.Orden cancelar(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable int id,
            @Valid @RequestBody CancelarOrden datos) {
        return ordenes.cancelar(actor.getUsuarioId(), id, datos.motivo());
    }

    public record NuevaOrden(
            @NotNull @Min(1) Integer equipoId,
            @NotBlank(message = "El problema es obligatorio.") @Size(max = 1000) String problema,
            @NotBlank(message = "Elegí una prioridad.") @Size(max = 10) String prioridad,
            @Future(message = "La fecha estimada debe ser posterior al momento actual.") OffsetDateTime fechaEstimada,
            @Size(max = 1000) String observaciones) {
        public NuevaOrden {
            problema = limpiar(problema); prioridad = limpiar(prioridad); observaciones = limpiar(observaciones);
        }
    }
    public record AsignarTecnico(@NotNull @Min(1) Integer tecnicoId, @Min(1) Integer tecnicoAnteriorId,
                                 @Size(max = 500) String observacion) {
        public AsignarTecnico { observacion = limpiar(observacion); }
    }
    public record CancelarOrden(@NotBlank(message = "Ingresá el motivo de cancelación.") @Size(max = 500) String motivo) {
        public CancelarOrden { motivo = limpiar(motivo); }
    }
    private static String limpiar(String texto) { return texto == null ? null : texto.strip(); }
}
