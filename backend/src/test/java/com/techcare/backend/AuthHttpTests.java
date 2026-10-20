package com.techcare.backend;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties="spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=TechCare;encrypt=false")
class AuthHttpTests {
    @LocalServerPort int port;
    @MockitoBean JdbcTemplate jdbc;

    @Test void cookieRealEsHttpOnlyRotaAlIngresarYNoSePuedeReutilizarTrasSalir() throws Exception {
        when(jdbc.queryForList(anyString(),any(Object[].class))).thenReturn(List.of(Map.ofEntries(
                Map.entry("UsuarioID",2),Map.entry("NombreUsuario","demo02"),Map.entry("EmpleadoID",2),
                Map.entry("PasswordHash","$pbkdf2-sha256$600000$HuxZL8PtNPKcYu8utgbkoQ==$NmPYFGhLXt0tyvkysSHHNFjQMIFqSF/tSTU66h3jzik="),
                Map.entry("AlgoritmoHash","PBKDF2_SHA256"),Map.entry("UsuarioActivo",true),Map.entry("EmpleadoActivo",true),
                Map.entry("Nombres","Usuario"),Map.entry("Apellidos","Prueba"),Map.entry("EmpleadoCodigo","EMP-002"),Map.entry("RolCodigo","RECEPCION"))));
        CookieManager cookies=new CookieManager(null,CookiePolicy.ACCEPT_ALL);
        HttpClient client=HttpClient.newBuilder().cookieHandler(cookies).build();
        HttpResponse<String> csrf=client.send(get("/api/auth/csrf"),HttpResponse.BodyHandlers.ofString());
        String setCookie=csrf.headers().firstValue("set-cookie").orElseThrow();
        assertTrue(setCookie.contains("HttpOnly"));
        assertTrue(setCookie.contains("SameSite=Lax"));
        String anterior=cookies.getCookieStore().getCookies().get(0).getValue();
        String token=JsonPath.read(csrf.body(),"$.token");
        HttpRequest entrar=HttpRequest.newBuilder(uri("/api/auth/login")).header("Content-Type","application/json")
                .header("X-CSRF-TOKEN",token).POST(HttpRequest.BodyPublishers.ofString("{\"nombreUsuario\":\"demo02\",\"contrasena\":\"TechCare2026!\"}")).build();
        assertEquals(200,client.send(entrar,HttpResponse.BodyHandlers.ofString()).statusCode());
        String autenticada=cookies.getCookieStore().getCookies().get(0).getValue();
        assertNotEquals(anterior,autenticada);
        assertEquals(200,client.send(get("/api/auth/sesion"),HttpResponse.BodyHandlers.ofString()).statusCode());
        HttpClient externo=HttpClient.newHttpClient();
        HttpRequest vieja=HttpRequest.newBuilder(uri("/api/auth/sesion")).header("Cookie","JSESSIONID="+anterior).GET().build();
        assertEquals(401,externo.send(vieja,HttpResponse.BodyHandlers.ofString()).statusCode());
        csrf=client.send(get("/api/auth/csrf"),HttpResponse.BodyHandlers.ofString());
        token=JsonPath.read(csrf.body(),"$.token");
        HttpRequest salir=HttpRequest.newBuilder(uri("/api/auth/logout")).header("X-CSRF-TOKEN",token).POST(HttpRequest.BodyPublishers.noBody()).build();
        assertEquals(200,client.send(salir,HttpResponse.BodyHandlers.ofString()).statusCode());
        HttpRequest reusar=HttpRequest.newBuilder(uri("/api/auth/sesion")).header("Cookie","JSESSIONID="+autenticada).GET().build();
        assertEquals(401,externo.send(reusar,HttpResponse.BodyHandlers.ofString()).statusCode());
    }
    private URI uri(String path) { return URI.create("http://127.0.0.1:"+port+path); }
    private HttpRequest get(String path) { return HttpRequest.newBuilder(uri(path)).GET().build(); }
}
