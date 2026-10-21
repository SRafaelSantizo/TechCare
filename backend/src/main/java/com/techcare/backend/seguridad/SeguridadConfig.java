package com.techcare.backend.seguridad;

import jakarta.servlet.DispatcherType;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.session.ChangeSessionIdAuthenticationStrategy;
import org.springframework.security.web.authentication.session.CompositeSessionAuthenticationStrategy;
import org.springframework.security.web.authentication.session.SessionAuthenticationStrategy;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.security.web.csrf.CsrfAuthenticationStrategy;
import org.springframework.security.web.csrf.CsrfException;
import org.springframework.security.web.csrf.HttpSessionCsrfTokenRepository;

import java.io.IOException;
import java.util.List;

@Configuration
public class SeguridadConfig {
    @Bean PasswordEncoder passwordEncoder() { return new TechCarePasswordEncoder(); }

    @Bean AuthenticationManager authenticationManager(UsuariosAcceso usuarios,PasswordEncoder encoder) {
        DaoAuthenticationProvider provider=new DaoAuthenticationProvider(usuarios);
        provider.setPasswordEncoder(encoder);
        return new ProviderManager(provider);
    }

    @Bean SecurityContextRepository contextRepository() { return new HttpSessionSecurityContextRepository(); }
    @Bean HttpSessionCsrfTokenRepository csrfRepository() { return new HttpSessionCsrfTokenRepository(); }

    @Bean SessionAuthenticationStrategy estrategiaSesion(HttpSessionCsrfTokenRepository csrf) {
        return new CompositeSessionAuthenticationStrategy(List.of(
                new ChangeSessionIdAuthenticationStrategy(),new CsrfAuthenticationStrategy(csrf)));
    }

    @Bean SecurityFilterChain seguridad(HttpSecurity http,AuthenticationManager manager,
            SecurityContextRepository context,HttpSessionCsrfTokenRepository csrf) throws Exception {
        return http.authenticationManager(manager)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .requestCache(AbstractHttpConfigurer::disable)
                .securityContext(c -> c.securityContextRepository(context).requireExplicitSave(true))
                .csrf(c -> c.csrfTokenRepository(csrf))
                .authorizeHttpRequests(a -> a
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                        .requestMatchers(HttpMethod.GET,"/api/auth/csrf").permitAll()
                        .requestMatchers(HttpMethod.POST,"/api/auth/login").permitAll()
                        .requestMatchers(HttpMethod.GET,"/api/auth/sesion").authenticated()
                        .requestMatchers(HttpMethod.GET,"/api/admin/usuarios","/api/admin/usuarios/*",
                                "/api/admin/roles","/api/admin/empleados-disponibles").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.POST,"/api/admin/usuarios").hasRole("ADMIN")
                        .requestMatchers(HttpMethod.GET,"/api/ordenes/catalogos/tecnicos").hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.GET,"/api/facturas","/api/caja/metodos-pago",
                                "/api/ordenes/*/factura/previa").hasAnyRole("ADMIN","CAJA")
                        .requestMatchers(HttpMethod.POST,"/api/ordenes/*/factura","/api/ordenes/*/factura/pagos")
                            .hasAnyRole("ADMIN","CAJA")
                        .requestMatchers(HttpMethod.POST,"/api/ordenes/*/entrega").hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.GET,"/api/ordenes","/api/ordenes/**")
                            .hasAnyRole("ADMIN","RECEPCION","TECNICO","CAJA")
                        .requestMatchers(HttpMethod.POST,"/api/ordenes","/api/ordenes/*/cancelacion")
                            .hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.POST,"/api/ordenes/*/diagnostico/inicio",
                                "/api/ordenes/*/diagnostico","/api/ordenes/*/reparacion",
                                "/api/ordenes/*/actividades","/api/ordenes/*/repuestos",
                                "/api/ordenes/*/reparacion/cierre").hasAnyRole("ADMIN","TECNICO")
                        .requestMatchers(HttpMethod.PUT,"/api/ordenes/*/tecnico").hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.GET,"/api/clientes","/api/clientes/**")
                            .hasAnyRole("ADMIN","RECEPCION","TECNICO","CAJA")
                        .requestMatchers(HttpMethod.POST,"/api/clientes").hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.PUT,"/api/clientes/*").hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.GET,"/api/equipos","/api/equipos/**","/api/catalogos/**")
                            .hasAnyRole("ADMIN","RECEPCION","TECNICO")
                        .requestMatchers(HttpMethod.POST,"/api/equipos").hasAnyRole("ADMIN","RECEPCION")
                        .requestMatchers(HttpMethod.PUT,"/api/equipos/*").hasAnyRole("ADMIN","RECEPCION")
                        .anyRequest().denyAll())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req,res,ex) -> json(res,401,
                                "{\"estado\":401,\"mensaje\":\"Iniciá sesión para continuar.\"}"))
                        .accessDeniedHandler((req,res,ex) -> json(res,403,ex instanceof CsrfException
                                ? "{\"estado\":403,\"codigo\":\"CSRF_INVALIDO\",\"mensaje\":\"La sesión de seguridad venció. Volvé a intentar.\"}"
                                : "{\"estado\":403,\"mensaje\":\"Tu usuario no tiene permiso para esta operación.\"}")))
                .logout(l -> l.logoutUrl("/api/auth/logout").invalidateHttpSession(true)
                        .clearAuthentication(true).deleteCookies("JSESSIONID")
                        .logoutSuccessHandler((req,res,auth) -> json(res,200,
                                "{\"autenticado\":false,\"usuario\":null,\"roles\":[]}")).permitAll())
                .build();
    }

    private static void json(HttpServletResponse response,int status,String body) throws IOException {
        response.setStatus(status);
        response.setCharacterEncoding("UTF-8");
        response.setContentType("application/json");
        response.getWriter().write(body);
    }
}
