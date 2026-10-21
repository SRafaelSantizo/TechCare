package com.techcare.backend.facturacion;

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
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class FacturacionApiTests {
    private static final String REVISION="A".repeat(64), UUID="1865330d-0a9b-4cc1-a4cd-265321081643";
    private static final String EMISION="{\"tasaImpuesto\":0.12,\"revision\":\""+REVISION+"\",\"usuarioId\":999}";
    private static final String ABONO="{\"solicitudId\":\""+UUID+"\",\"metodoPagoId\":1,\"monto\":25.50,\"saldoEsperado\":169.12,\"referencia\":\" Pago ñ \",\"usuarioId\":999}";
    @Autowired WebApplicationContext context;
    @MockitoBean JdbcTemplate jdbc;
    @MockitoBean PlatformTransactionManager transacciones;
    private MockMvc mvc;
    @BeforeEach void preparar() {
        reset(jdbc,transacciones);
        when(transacciones.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenReturn(List.of(factura()));
        mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
    }
    private Map<String,Object> factura() {
        var r=new HashMap<String,Object>();
        r.put("FacturaID",7);r.put("OrdenID",81);r.put("NumeroFactura","TCF-45");r.put("NumeroOrden","TC-81");
        r.put("Fecha",Timestamp.valueOf("2026-10-21 18:30:00"));r.put("Estado","EMITIDA");
        r.put("NombreFacturacion","María José Núñez");r.put("NITFacturacion","1234567-8");
        r.put("TasaImpuesto",new BigDecimal("0.12"));
        for(String k:List.of("Subtotal","ManoObra","Repuestos","Impuesto","Total","Pagado","Saldo"))r.put(k,new BigDecimal("25.50"));
        r.put("Tecnico","Óscar Muñoz");r.put("Recepcionista","Lucía Pérez");r.put("EmitidaPor","Ana López");
        r.put("PasswordHash","NO_SERIALIZAR");r.put("CostoReferencia",12);
        return r;
    }
    private RequestPostProcessor actor(String rol) {
        var u=new UsuarioAutenticado(42,"cuenta","Persona prueba","EMP-42",List.of(rol),true,null);
        return authentication(UsernamePasswordAuthenticationToken.authenticated(u,null,u.getAuthorities()));
    }
    @ParameterizedTest @ValueSource(strings={"TECNICO","RECEPCION","BODEGA"})
    void emitirAbonarYVistaPreviaSonSoloDeCaja(String rol) throws Exception {
        for(String ruta:List.of("factura","factura/pagos")) mvc.perform(post("/api/ordenes/81/"+ruta).with(actor(rol)).with(csrf())
                .contentType("application/json").content(EMISION)).andExpect(status().isForbidden());
        mvc.perform(get("/api/ordenes/81/factura/previa").with(actor(rol))).andExpect(status().isForbidden());
        mvc.perform(get("/api/facturas").with(actor(rol))).andExpect(status().isForbidden());
        verifyNoInteractions(jdbc);
    }
    @ParameterizedTest @ValueSource(strings={"TECNICO","CAJA","BODEGA"})
    void cajaNoReemplazaARecepcionEnLaEntrega(String rol) throws Exception {
        mvc.perform(post("/api/ordenes/81/entrega").with(actor(rol)).with(csrf()).contentType("application/json")
                .content("{\"nombreRecibe\":\"María\"}")).andExpect(status().isForbidden());verifyNoInteractions(jdbc);
    }
    @Test void escriturasExigenSesionYCsrf() throws Exception {
        for(String ruta:List.of("factura","factura/pagos","entrega")) {
            mvc.perform(post("/api/ordenes/81/"+ruta).with(csrf()).contentType("application/json").content(EMISION)).andExpect(status().isUnauthorized());
            mvc.perform(post("/api/ordenes/81/"+ruta).with(actor("ADMIN")).contentType("application/json").content(EMISION)).andExpect(status().isForbidden());
        }
        verifyNoInteractions(jdbc);
    }
    @Test void emisionYAbonoUsanActorDeSesionYClaveDelIntento() throws Exception {
        mvc.perform(post("/api/ordenes/81/factura").with(actor("CAJA")).with(csrf()).contentType("application/json").content(EMISION))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.tecnico").value("Óscar Muñoz"))
                .andExpect(jsonPath("$.recepcionista").value("Lucía Pérez"))
                .andExpect(content().string(not(containsString("NO_SERIALIZAR")))).andExpect(content().string(not(containsString("CostoReferencia"))));
        mvc.perform(post("/api/ordenes/81/factura/pagos").with(actor("CAJA")).with(csrf()).contentType("application/json").content(ABONO)).andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spEmitirFacturaOrden ?, ?, ?, ?",42,81,new BigDecimal("0.12"),REVISION);
        verify(jdbc).queryForList("EXEC dbo.spAbonarFacturaOrden ?, ?, ?, ?, ?, ?, ?",42,81,UUID,1,new BigDecimal("25.50"),new BigDecimal("169.12"),"Pago ñ");
    }
    @Test void receptorUnicodeSeConservaYSoloSesionIndicaQuienEntrega() throws Exception {
        mvc.perform(post("/api/ordenes/81/entrega").with(actor("RECEPCION")).with(csrf()).contentType("application/json")
                .content("{\"nombreRecibe\":\" María José ñ \",\"documentoRecibe\":\" 1234-5 \",\"observaciones\":\" Probado ñ \",\"usuarioEntregaId\":999}"))
                .andExpect(status().isOk());
        verify(jdbc).queryForList("EXEC dbo.spRegistrarEntregaOrden ?, ?, ?, ?, ?",42,81,"María José ñ","1234-5","Probado ñ");
    }
    @ParameterizedTest @ValueSource(strings={"0","-1","1.234","10000000000","null"})
    void noSeRedondeanNiAceptanImportesFueraDeLimite(String monto) throws Exception {
        mvc.perform(post("/api/ordenes/81/factura/pagos").with(actor("CAJA")).with(csrf()).contentType("application/json")
                .content(ABONO.replace("25.50",monto))).andExpect(status().isBadRequest()); verifyNoInteractions(jdbc);
    }
    @Test void metodoFraccionarioUuidInvalidoYTasaInvalidaNoLleganASql() throws Exception {
        for(String body:List.of(ABONO.replace("\"metodoPagoId\":1","\"metodoPagoId\":1.5"),ABONO.replace(UUID,"invalido"),ABONO.replace("Pago ñ","x".repeat(101))))
            mvc.perform(post("/api/ordenes/81/factura/pagos").with(actor("CAJA")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());
        for(String tasa:List.of("-0.1","1.1","0.12345")) {
            mvc.perform(get("/api/ordenes/81/factura/previa").param("tasaImpuesto",tasa).with(actor("CAJA"))).andExpect(status().isBadRequest());
            mvc.perform(post("/api/ordenes/81/factura").with(actor("CAJA")).with(csrf()).contentType("application/json").content(EMISION.replace("0.12",tasa))).andExpect(status().isBadRequest());
        }
        verifyNoInteractions(jdbc);
    }
    @Test void textosDeEntregaNoSeTruncan() throws Exception {
        for(String body:List.of("{\"nombreRecibe\":\" \"}","{\"nombreRecibe\":\""+"x".repeat(151)+"\"}",
                "{\"nombreRecibe\":\"María\",\"documentoRecibe\":\""+"1".repeat(31)+"\"}","{\"nombreRecibe\":\"María\",\"observaciones\":\""+"x".repeat(1001)+"\"}"))
            mvc.perform(post("/api/ordenes/81/entrega").with(actor("RECEPCION")).with(csrf()).contentType("application/json").content(body)).andExpect(status().isBadRequest());
        verifyNoInteractions(jdbc);
    }
    @Test void consultasSinFacturaSonNulasYListasVacias() throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenReturn(List.of());
        mvc.perform(get("/api/ordenes/81/factura").with(actor("RECEPCION"))).andExpect(status().isOk()).andExpect(content().string(""));
        mvc.perform(get("/api/ordenes/81/factura/pagos").with(actor("RECEPCION"))).andExpect(status().isOk()).andExpect(content().json("[]"));
        mvc.perform(get("/api/ordenes/81/entrega").with(actor("RECEPCION"))).andExpect(status().isOk()).andExpect(content().string(""));
    }
    @Test void pdfTieneTipoNombreDescargaYNoSeGuardaEnCache() throws Exception {
        when(jdbc.queryForList("EXEC dbo.spDetalleFacturaOrden ?, ?",42,81)).thenReturn(List.of(Map.of("Linea",1,"Concepto","Mano de obra ñ","Cantidad",1,"PrecioUnitario",new BigDecimal("25.50"),"Importe",new BigDecimal("25.50"))));
        when(jdbc.queryForList("EXEC dbo.spPagosFacturaOrden ?, ?",42,81)).thenReturn(List.of());
        when(jdbc.queryForList("EXEC dbo.spConsultarEntregaOrden ?, ?",42,81)).thenReturn(List.of());
        mvc.perform(get("/api/ordenes/81/factura/pdf").with(actor("RECEPCION")).accept("application/pdf"))
                .andExpect(status().isOk()).andExpect(content().contentType("application/pdf"))
                .andExpect(header().string("Content-Disposition",containsString("Factura-TCF-45.pdf")))
                .andExpect(header().string("Cache-Control","no-store"))
                .andExpect(result -> org.junit.jupiter.api.Assertions.assertTrue(new String(result.getResponse().getContentAsByteArray(),0,5,java.nio.charset.StandardCharsets.US_ASCII).startsWith("%PDF-")));
    }
    @Test void pdfSinFacturaDevuelveErrorJsonInclusoSiSeSolicitoPdf() throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenReturn(List.of());
        mvc.perform(get("/api/ordenes/81/factura/pdf").with(actor("RECEPCION")).accept("application/pdf"))
                .andExpect(status().isNotFound()).andExpect(content().contentTypeCompatibleWith("application/json"));
    }
    @ParameterizedTest @CsvSource({"51800,400","51802,404","51803,409","51804,403","51038,409","51131,409","2812,503"})
    void erroresSqlMantienenContratoSinExponerDatosInternos(int codigo,int estado) throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenThrow(new UncategorizedSQLException("caja","EXEC",new SQLException("Detalle SQL privado","S0001",codigo)));
        var r=mvc.perform(post("/api/ordenes/81/factura/pagos").with(actor("CAJA")).with(csrf()).contentType("application/json").content(ABONO)).andExpect(status().is(estado));
        if(estado==403||estado==404||estado==503)r.andExpect(content().string(not(containsString("Detalle SQL privado"))));
    }
    @Test void lecturaAjenaSeRechazaAntesDeGenerarPdf() throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenThrow(new UncategorizedSQLException("caja","EXEC",new SQLException("privado","S0001",51802)));
        mvc.perform(get("/api/ordenes/81/factura/pdf").with(actor("TECNICO"))).andExpect(status().isNotFound());
        verify(jdbc).queryForList("EXEC dbo.spConsultarFacturaOrden ?, ?",42,81);verifyNoMoreInteractions(jdbc);
    }
}
