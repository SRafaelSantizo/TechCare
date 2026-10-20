package com.techcare.backend;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/catalogos")
public class CatalogoEquipoController {
    private final JdbcTemplate jdbc;

    public CatalogoEquipoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/tipos-equipos")
    public List<Map<String, Object>> tipos() {
        return jdbc.queryForList("EXEC dbo.spListarTiposEquipo");
    }

    @GetMapping("/marcas")
    public List<Map<String, Object>> marcas() {
        return jdbc.queryForList("EXEC dbo.spListarMarcas");
    }

    @GetMapping("/modelos-equipos")
    public List<Map<String, Object>> modelos(
            @RequestParam(name = "marcaId", required = false) Integer marcaId,
            @RequestParam(name = "tipoEquipoId", required = false) Integer tipoEquipoId) {
        return jdbc.queryForList("EXEC dbo.spListarModelosEquipo ?, ?", marcaId, tipoEquipoId);
    }
}
