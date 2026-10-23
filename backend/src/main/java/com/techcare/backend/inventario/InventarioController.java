package com.techcare.backend.inventario;

import com.techcare.backend.seguridad.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/inventario")
public class InventarioController {
    private final InventarioServicio servicio;
    public InventarioController(InventarioServicio servicio) { this.servicio=servicio; }

    @GetMapping
    public InventarioServicio.Inventario listar(@AuthenticationPrincipal UsuarioAutenticado usuario,
            @RequestParam(required=false) String buscar,@RequestParam(required=false) Integer bodegaId,
            @RequestParam(required=false) Integer categoriaId,@RequestParam(required=false) String estadoStock,
            @RequestParam(required=false) Boolean activo,@RequestParam(defaultValue="1") int pagina,
            @RequestParam(defaultValue="25") int tamano) {
        return servicio.listar(usuario.getUsuarioId(),buscar,bodegaId,categoriaId,estadoStock,activo,pagina,tamano);
    }

    @GetMapping("/{bodegaId}/{repuestoId}/kardex")
    public InventarioServicio.Kardex kardex(@AuthenticationPrincipal UsuarioAutenticado usuario,
            @PathVariable int bodegaId,@PathVariable int repuestoId,@RequestParam(required=false) LocalDate desde,
            @RequestParam(required=false) LocalDate hasta,@RequestParam(required=false) String tipo,
            @RequestParam(defaultValue="1") int pagina,@RequestParam(defaultValue="25") int tamano) {
        return servicio.kardex(usuario.getUsuarioId(),bodegaId,repuestoId,desde,hasta,tipo,pagina,tamano);
    }
}
