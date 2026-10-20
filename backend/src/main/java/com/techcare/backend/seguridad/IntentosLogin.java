package com.techcare.backend.seguridad;

import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

@Component
public class IntentosLogin {
    private static final long VENTANA=Duration.ofMinutes(5).toMillis();
    private final Map<String,Ventana> intentos=new HashMap<>();
    private final Clock clock;
    public IntentosLogin() { this(Clock.systemUTC()); }
    IntentosLogin(Clock clock) { this.clock=clock; }

    public synchronized boolean permitir(String usuario,String direccion) {
        long ahora=clock.millis();
        intentos.entrySet().removeIf(e -> ahora-e.getValue().inicio()>=VENTANA);
        String clave=clave(usuario,direccion);
        Ventana anterior=intentos.get(clave);
        if (anterior==null && intentos.size()>=10_000) return false;
        int cantidad=anterior==null ? 0 : anterior.cantidad();
        if (cantidad>=10) return false;
        intentos.put(clave,new Ventana(anterior==null ? ahora : anterior.inicio(),cantidad+1));
        return true;
    }
    public synchronized void exito(String usuario,String direccion) { intentos.remove(clave(usuario,direccion)); }
    private String clave(String usuario,String direccion) { return direccion+"|"+usuario.toLowerCase(Locale.ROOT); }
    private record Ventana(long inicio,int cantidad) {}
}
