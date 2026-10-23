package com.techcare.backend.reportes;
import com.techcare.backend.seguridad.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/reportes")
public class ReportesController {
 private final ReportesServicio servicio;
 public ReportesController(ReportesServicio servicio) { this.servicio=servicio; }
 @GetMapping
 public List<ReportesContrato.Definicion> catalogo(@AuthenticationPrincipal UsuarioAutenticado u) { return servicio.catalogo(u.getUsuarioId()); }
 @GetMapping("/{codigo}")
 public ReportesServicio.Resultado consultar(@AuthenticationPrincipal UsuarioAutenticado u,@PathVariable String codigo,@RequestParam MultiValueMap<String,String> filtros) {
  return servicio.consultar(u.getUsuarioId(),codigo,filtros);
 }
 @GetMapping("/{codigo}/opciones")
 public List<ReportesServicio.Opcion> opciones(@AuthenticationPrincipal UsuarioAutenticado u,@PathVariable String codigo,
   @RequestParam String tipo,@RequestParam(required=false) String buscar) { return servicio.opciones(u.getUsuarioId(),codigo,tipo,buscar); }
}
