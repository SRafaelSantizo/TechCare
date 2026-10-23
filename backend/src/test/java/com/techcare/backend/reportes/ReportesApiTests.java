package com.techcare.backend.reportes;
import com.techcare.backend.seguridad.UsuarioAutenticado;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.UncategorizedSQLException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.web.context.WebApplicationContext;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.*;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class ReportesApiTests {
 @Autowired WebApplicationContext context;
 @MockitoBean JdbcTemplate jdbc;
 @MockitoBean PlatformTransactionManager transactions;
 private MockMvc mvc;
 private Map<String,Object> fila,resumen;
 @BeforeEach void preparar() {
  reset(jdbc,transactions);when(transactions.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
  mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
  fila=new HashMap<>();fila.putAll(Map.of("OrdenID",7,"NumeroOrden","OS-7","Cliente","Cliente ñ 漢字","NumeroSerie","SER-7","Tecnico","Técnico ñ","FechaIngreso",Timestamp.valueOf("2026-10-23 10:20:30"),"PasswordHash","PRIVADO","LoginSQL","INTERNO"));
  fila.putAll(Map.of("Total",new BigDecimal("79.52"),"Saldo",new BigDecimal("49.52"),"CostoPromedio",new BigDecimal("15.571429"),"ValorExistencia",new BigDecimal("21474836469978525163.530000"),"MovimientoID",9007199254740993L,"Existencia",9007199254740995L,"Mes",java.sql.Date.valueOf("2026-10-01")));
  fila.put("HistorialEstados","[{\"EstadoNuevo\":\"RECIBIDO\",\"Observacion\":\"Garantía ñ 漢字\"}]");
  fila.put("RepuestosYMovimientos","[{\"Cantidad\":1,\"CostoUnitario\":\"12.25\",\"MovimientoID\":\"9007199254740993\"}]");
  fila.put("Pagos","[{\"Monto\":\"20.00\"},{\"Monto\":\"10.00\"}]");
  resumen=new HashMap<>();resumen.putAll(Map.of("Total",60L,"Facturas",1L,"TotalFacturado",new BigDecimal("79.52"),"PagadoTotal",new BigDecimal("30.00"),"SaldoTotal",new BigDecimal("49.52"),"ValorTotal",new BigDecimal("21474836469978525163.530000")));
  when(jdbc.queryForList(anyString(),any(Object[].class))).thenAnswer(i->{
   String sql=i.getArgument(0);Object[] args=(Object[])i.getRawArguments()[1];
   if(sql.contains("spCatalogoReportesApi"))return List.of(Map.of("Codigo","R01"),Map.of("Codigo","R12"));
   if(sql.contains("spOpcionesReporteApi"))return List.of(Map.of("Valor","42","Etiqueta","Técnico ñ 漢字","PasswordHash","PRIVADO"));
   return List.of(Boolean.TRUE.equals(args[13])?resumen:fila);
  });
 }
 private RequestPostProcessor actor(String rol) {
  var u=new UsuarioAutenticado(42,"personal","Personal prueba","EMP-42",List.of(rol),true,null);
  return authentication(UsernamePasswordAuthenticationToken.authenticated(u,null,u.getAuthorities()));
 }
 @Test void todasLasRutasExigenSesion() throws Exception {
  for(String p:List.of("/api/reportes","/api/reportes/R01","/api/reportes/R01/opciones?tipo=tecnicoId"))mvc.perform(get(p)).andExpect(status().isUnauthorized());verifyNoInteractions(jdbc);
 }
 @ParameterizedTest @ValueSource(strings={"ADMIN","RECEPCION","TECNICO","BODEGA","CAJA"})
 void catalogoConsultaPermisosConElActorAutenticado(String rol) throws Exception {
  mvc.perform(get("/api/reportes").with(actor(rol))).andExpect(status().isOk()).andExpect(jsonPath("$[0].codigo").value("R01")).andExpect(jsonPath("$[0].columnas",hasSize(9)));
  verify(jdbc).queryForList("EXEC dbo.spCatalogoReportesApi ?",42);
 }
 @ParameterizedTest @ValueSource(strings={"R01","R02","R03","R04","R05","R06","R07","R08","R09","R10","R11","R12"})
 void doceReportesSerializanColumnasDeclaradasYResumenTransaccional(String codigo) throws Exception {
  mvc.perform(get("/api/reportes/"+codigo).with(actor("ADMIN"))).andExpect(status().isOk()).andExpect(jsonPath("$.codigo").value(codigo)).andExpect(jsonPath("$.total").value(60)).andExpect(jsonPath("$.totalPaginas").value(3))
   .andExpect(content().string(not(containsString("PRIVADO")))).andExpect(content().string(not(containsString("INTERNO"))));
  verify(transactions).getTransaction(argThat(t->t.isReadOnly()&&t.getIsolationLevel()==TransactionDefinition.ISOLATION_SERIALIZABLE));verify(transactions).commit(any());
 }
 @Test void importesYBigintNoPierdenDigitos() throws Exception {
  mvc.perform(get("/api/reportes/R06").with(actor("BODEGA"))).andExpect(status().isOk())
   .andExpect(jsonPath("$.filas[0].Existencia").value("9007199254740995")).andExpect(jsonPath("$.filas[0].CostoPromedio").value("15.571429"))
   .andExpect(jsonPath("$.filas[0].ValorExistencia").value("21474836469978525163.530000"));
  mvc.perform(get("/api/reportes/R09").with(actor("ADMIN"))).andExpect(jsonPath("$.filas[0].MovimientoID").value("9007199254740993"));
 }
 @Test void fechasOuterUtcYMesNoSeConviertenAFlotantes() throws Exception {
  mvc.perform(get("/api/reportes/R01").with(actor("ADMIN"))).andExpect(jsonPath("$.filas[0].FechaIngreso").value("2026-10-23T10:20:30Z"));
  mvc.perform(get("/api/reportes/R11").with(actor("CAJA"))).andExpect(jsonPath("$.filas[0].Mes").value("2026-10-01"));
 }
 @Test void detalleR12ConservaListasIndependientesYTextoUnicode() throws Exception {
  mvc.perform(get("/api/reportes/R12").with(actor("ADMIN"))).andExpect(jsonPath("$.filas[0].HistorialEstados").value(containsString("Garantía ñ 漢字")))
   .andExpect(jsonPath("$.filas[0].Pagos").value("[{\"Monto\":\"20.00\"},{\"Monto\":\"10.00\"}]"));
 }
 @Test void resumenFinancieroProvieneDeSqlSinSumarFilasEnJava() throws Exception {
  mvc.perform(get("/api/reportes/R10").with(actor("CAJA"))).andExpect(jsonPath("$.indicadores[0].valor").value("1"))
   .andExpect(jsonPath("$.indicadores[1].valor").value("79.52")).andExpect(jsonPath("$.indicadores[2].valor").value("30.00")).andExpect(jsonPath("$.indicadores[3].valor").value("49.52"));
 }
 @Test void parametrosFechasYFiltrosTienenPosicionesFijas() throws Exception {
  mvc.perform(get("/api/reportes/r01").with(actor("TECNICO")).param("tecnicoId","42").param("estado","RECIBIDO").param("desde","2026-10-01").param("hasta","2026-10-23").param("pagina","2").param("tamano","10")).andExpect(status().isOk());
  verify(jdbc).queryForList(anyString(),eq(42),eq("R01"),eq(LocalDate.of(2026,10,1)),eq(LocalDate.of(2026,10,23)),isNull(),eq(42),isNull(),isNull(),isNull(),isNull(),isNull(),eq("RECIBIDO"),isNull(),eq(true),eq(1),eq(10));
  verify(jdbc).queryForList(anyString(),eq(42),eq("R01"),eq(LocalDate.of(2026,10,1)),eq(LocalDate.of(2026,10,23)),isNull(),eq(42),isNull(),isNull(),isNull(),isNull(),isNull(),eq("RECIBIDO"),isNull(),eq(false),eq(2),eq(10));
 }
 @Test void busquedaLiteralSeEnviaComoParametro() throws Exception {
  mvc.perform(get("/api/reportes/R08/opciones").with(actor("BODEGA")).param("tipo","proveedorId").param("buscar","%_' OR 1=1")).andExpect(status().isOk()).andExpect(content().string(not(containsString("PRIVADO"))));
  verify(jdbc).queryForList("EXEC dbo.spOpcionesReporteApi ?, ?, ?, ?",42,"R08","proveedorId","%_' OR 1=1");
 }
 @ParameterizedTest @ValueSource(strings={"/R01?clienteId=1","/R01?usuarioActorId=999","/R01?pagina=0","/R01?tamano=101","/R01?tecnicoId=1.5","/R01?tecnicoId=2147483648","/R01?tecnicoId=-1","/R01?tecnicoId=1&tecnicoId=2","/R01?desde=2026-02-30","/R01?desde=0000-01-01","/R01?desde=2026-10-23&hasta=2026-10-01","/R11?bodegaId=1","/R03?serie="})
 void filtrosInvalidosSeRechazanSinConsultarSql(String path) throws Exception {
  if(path.equals("/R03?serie="))path="/R03?serie="+"x".repeat(81);
  mvc.perform(get("/api/reportes"+path).with(actor("ADMIN"))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
 }
 @Test void codigosYCatalogosAjenosSeRechazan() throws Exception {
  mvc.perform(get("/api/reportes/R99").with(actor("ADMIN"))).andExpect(status().isNotFound());
  mvc.perform(get("/api/reportes/R01/opciones?tipo=clienteId").with(actor("ADMIN"))).andExpect(status().isBadRequest());verifyNoInteractions(jdbc);
 }
 @Test void paginaFueraDeRangoSeAjustaSinAlterarTotal() throws Exception {
  mvc.perform(get("/api/reportes/R01?pagina=2147483647").with(actor("ADMIN"))).andExpect(jsonPath("$.pagina").value(3));
  verify(jdbc).queryForList(anyString(),eq(42),eq("R01"),isNull(),isNull(),isNull(),isNull(),isNull(),isNull(),isNull(),isNull(),isNull(),isNull(),isNull(),eq(false),eq(3),eq(25));
 }
 @Test void consultaVaciaConservaResumenCero() throws Exception {
  resumen.put("Total",0L);
  when(jdbc.queryForList(anyString(),any(Object[].class))).thenAnswer(i->Boolean.TRUE.equals(((Object[])i.getRawArguments()[1])[13])?List.of(resumen):List.of());
  mvc.perform(get("/api/reportes/R01").with(actor("ADMIN"))).andExpect(jsonPath("$.filas",hasSize(0))).andExpect(jsonPath("$.total").value(0)).andExpect(jsonPath("$.pagina").value(1));
 }
 @Test void moduloNoTieneEscriturasNiAceptaRolesDesconocidos() throws Exception {
  mvc.perform(get("/api/reportes").with(actor("OTRO"))).andExpect(status().isForbidden());
  for(var metodo:List.of(org.springframework.http.HttpMethod.POST,org.springframework.http.HttpMethod.PUT,org.springframework.http.HttpMethod.DELETE))
   mvc.perform(request(metodo,"/api/reportes/R01").with(actor("ADMIN")).with(csrf())).andExpect(status().isForbidden());verifyNoInteractions(jdbc);
 }
 @ParameterizedTest @CsvSource({"52300,400","52302,404","52304,403","1205,409","1222,409","2812,503"})
 void erroresSqlMantienenContratoSinExponerDetalles(int codigo,int estado) throws Exception {
  when(jdbc.queryForList(anyString(),any(Object[].class))).thenThrow(new UncategorizedSQLException("reporte","EXEC",new SQLException("INTERNO_SQL","S0001",codigo)));
  mvc.perform(get("/api/reportes/R01").with(actor("TECNICO"))).andExpect(status().is(estado)).andExpect(content().string(not(containsString("INTERNO_SQL"))));
 }
}
