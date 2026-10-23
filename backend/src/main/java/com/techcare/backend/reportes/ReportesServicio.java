package com.techcare.backend.reportes;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.MultiValueMap;
import org.springframework.web.server.ResponseStatusException;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.*;
import java.time.format.DateTimeParseException;
import java.util.*;

@Service
public class ReportesServicio {
 private static final String CONSULTA="EXEC dbo.spConsultarReporteApi ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?";
 private final JdbcTemplate jdbc;
 public ReportesServicio(JdbcTemplate jdbc) { this.jdbc=jdbc; }
 public List<ReportesContrato.Definicion> catalogo(int actor) {
  return jdbc.queryForList("EXEC dbo.spCatalogoReportesApi ?",actor).stream().map(r->ReportesContrato.obtener(String.valueOf(r.get("Codigo")))).toList();
 }
 public List<Opcion> opciones(int actor,String codigo,String tipo,String buscar) {
  var r=ReportesContrato.obtener(codigo);
  if(!r.filtros().contains(tipo)||List.of("serie","desde","hasta").contains(tipo))mal("El reporte no ofrece ese catálogo de filtros.");
  if(buscar!=null&&buscar.length()>150)mal("La búsqueda admite hasta 150 caracteres.");
  return jdbc.queryForList("EXEC dbo.spOpcionesReporteApi ?, ?, ?, ?",actor,r.codigo(),tipo,buscar).stream()
    .map(row->new Opcion(texto(row.get("Valor")),texto(row.get("Etiqueta")))).toList();
 }
 @Transactional(readOnly=true,isolation=Isolation.SERIALIZABLE)
 public Resultado consultar(int actor,String codigo,MultiValueMap<String,String> entrada) {
  var reporte=ReportesContrato.obtener(codigo);var valores=new HashMap<String,String>();
  entrada.forEach((k,v)->{
   if((!reporte.filtros().contains(k)&&!List.of("pagina","tamano").contains(k))||v.size()!=1)mal("El filtro "+k+" no es válido para este reporte.");
   String s=v.get(0);if(s!=null&&!s.isBlank())valores.put(k,s.strip());
  });
  LocalDate desde=fechaFiltro(valores.get("desde")),hasta=fechaFiltro(valores.get("hasta"));
  if(desde!=null&&hasta!=null&&desde.isAfter(hasta))mal("La fecha inicial no puede ser posterior a la final.");
  String serie=valores.get("serie"),estado=valores.get("estado");
  if(serie!=null&&serie.length()>80)mal("La serie admite hasta 80 caracteres.");
  if(estado!=null&&estado.length()>30)mal("El estado admite hasta 30 caracteres.");
  int pagina=numero(valores.get("pagina"),1),tamano=numero(valores.get("tamano"),25);
  if(tamano>100)mal("El tamaño de página debe estar entre 1 y 100.");
  Object[] args={actor,reporte.codigo(),desde,hasta,id(valores,"clienteId"),id(valores,"tecnicoId"),id(valores,"bodegaId"),id(valores,"proveedorId"),id(valores,"ordenId"),id(valores,"categoriaId"),id(valores,"repuestoId"),estado,serie,true,1,tamano};
  var cabeceras=jdbc.queryForList(CONSULTA,args);
  if(cabeceras.isEmpty())throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"No se pudo obtener el resumen del reporte.");
  var resumen=cabeceras.get(0);long total=resumen.get("Total") instanceof Number n?n.longValue():0;
  long paginas=Math.max(1,(total-1)/tamano+1);int actual=(int)Math.min(pagina,paginas);
  Object[] detalle=args.clone();detalle[13]=false;detalle[14]=actual;
  var filas=jdbc.queryForList(CONSULTA,detalle).stream().map(fila->{
   var segura=new LinkedHashMap<String,String>();
   for(var c:reporte.columnas())segura.put(c.clave(),texto(fila.get(c.clave())));
   return segura;
  }).toList();
  var indicadores=reporte.indicadores().stream().map(i->new Indicador(i.titulo(),i.tipo(),texto(resumen.get(i.clave())))).toList();
  return new Resultado(reporte.codigo(),reporte.titulo(),filas,indicadores,actual,tamano,total,paginas);
 }
 private static Integer id(Map<String,String> v,String k) { return v.containsKey(k)?numero(v.get(k),1):null; }
 private static int numero(String s,int defecto) {
  if(s==null)return defecto;
  try { if(!s.matches("[1-9][0-9]{0,9}"))throw new NumberFormatException();return Integer.parseInt(s); }
  catch(NumberFormatException e) { mal("Los identificadores, la página y el tamaño deben ser enteros positivos.");return 0; }
 }
 private static LocalDate fechaFiltro(String s) {
  if(s==null)return null;
  try { var d=LocalDate.parse(s);if(d.getYear()<1||d.getYear()>9999)throw new DateTimeParseException("rango",s,0);return d; }
  catch(DateTimeParseException e) { mal("Ingresá una fecha válida entre los años 1 y 9999.");return null; }
 }
 private static void mal(String s) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,s); }
 private static String texto(Object v) {
  if(v==null)return null;if(v instanceof BigDecimal d)return d.toPlainString();
  if(v instanceof Timestamp t)return t.toLocalDateTime().atOffset(ZoneOffset.UTC).toString();
  if(v instanceof LocalDateTime t)return t.atOffset(ZoneOffset.UTC).toString();
  if(v instanceof java.sql.Date d)return d.toLocalDate().toString();
  return v.toString();
 }
 public record Opcion(String valor,String etiqueta) {}
 public record Indicador(String titulo,String tipo,String valor) {}
 public record Resultado(String codigo,String titulo,List<LinkedHashMap<String,String>> filas,List<Indicador> indicadores,int pagina,int tamano,long total,long totalPaginas) {}
}
