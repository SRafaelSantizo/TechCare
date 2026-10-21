package com.techcare.backend;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.dao.DataRetrievalFailureException;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/equipos")
public class EquipoController {
    private final JdbcTemplate jdbc;

    public EquipoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Map<String, Object>> listar(
            @RequestParam(name = "clienteId", required = false) Integer clienteId,
            @RequestParam(name = "serie", required = false) String serie,
            @RequestParam(name = "activo", required = false) Boolean activo) {
        return jdbc.queryForList("EXEC dbo.spListarEquipos ?, ?, ?", clienteId, serie, activo);
    }

    @GetMapping("/{id}")
    public Map<String, Object> consultar(@PathVariable("id") int id) {
        return unaFila(jdbc.queryForList("EXEC dbo.spConsultarEquipo ?", id));
    }

    @GetMapping("/{id}/historial")
    public List<Map<String, Object>> historial(@AuthenticationPrincipal UsuarioAutenticado actor, @PathVariable("id") int id) {
        return jdbc.queryForList("EXEC dbo.spHistorialEquipoAcceso ?, ?", actor.getUsuarioId(), id);
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> registrar(@Valid @RequestBody EquipoDatos datos) {
        Map<String, Object> equipo = unaFila(jdbc.queryForList(
                "EXEC dbo.spRegistrarEquipo ?, ?, ?, ?, ?",
                datos.clienteId(), datos.modeloEquipoId(), datos.numeroSerie(), datos.descripcion(), datos.activo()));
        Number id = (Number) equipo.get("EquipoID");
        return ResponseEntity.created(URI.create("/api/equipos/" + id.intValue())).body(equipo);
    }

    @PutMapping("/{id}")
    public Map<String, Object> actualizar(@PathVariable("id") int id, @Valid @RequestBody EquipoDatos datos) {
        return unaFila(jdbc.queryForList("EXEC dbo.spActualizarEquipo ?, ?, ?, ?, ?, ?",
                id, datos.clienteId(), datos.modeloEquipoId(), datos.numeroSerie(), datos.descripcion(), datos.activo()));
    }

    private Map<String, Object> unaFila(List<Map<String, Object>> filas) {
        if (filas.size() != 1 || !(filas.get(0).get("EquipoID") instanceof Number)) {
            throw new DataRetrievalFailureException("El procedimiento no devolvió un equipo válido.");
        }
        return filas.get(0);
    }

    public record EquipoDatos(
            @NotNull(message = "El cliente es obligatorio.") @Min(value = 1, message = "Elegí un cliente válido.")
            Integer clienteId,
            @NotNull(message = "El modelo es obligatorio.") @Min(value = 1, message = "Elegí un modelo válido.")
            Integer modeloEquipoId,
            @NotBlank(message = "La serie es obligatoria.") @Size(max = 80, message = "La serie admite hasta 80 caracteres.")
            String numeroSerie,
            @NotBlank(message = "La descripción es obligatoria.") @Size(max = 500, message = "La descripción admite hasta 500 caracteres.")
            String descripcion,
            @NotNull(message = "Activo es obligatorio: usá true o false.") Boolean activo) {
        public EquipoDatos {
            numeroSerie = numeroSerie == null ? null : numeroSerie.strip();
            descripcion = descripcion == null ? null : descripcion.strip();
        }
    }
}
