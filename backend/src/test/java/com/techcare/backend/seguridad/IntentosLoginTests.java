package com.techcare.backend.seguridad;

import org.junit.jupiter.api.Test;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import static org.junit.jupiter.api.Assertions.*;

class IntentosLoginTests {
    @Test void limitaIntentosPorUsuarioYDireccionSinDistinguirMayusculas() {
        IntentosLogin intentos=new IntentosLogin();
        for (int i=0;i<10;i++) assertTrue(intentos.permitir("DEMO01","127.0.0.1"));
        assertFalse(intentos.permitir("demo01","127.0.0.1"));
        assertTrue(intentos.permitir("demo01","127.0.0.2"));
        assertTrue(intentos.permitir("demo02","127.0.0.1"));
    }
    @Test void accesoCorrectoLimpiaElContador() {
        IntentosLogin intentos=new IntentosLogin();
        for (int i=0;i<10;i++) intentos.permitir("demo01","local");
        intentos.exito("demo01","local");
        assertTrue(intentos.permitir("demo01","local"));
    }
    @Test void permiteOtroIntentoAlVencerLaVentana() {
        Reloj reloj=new Reloj();
        IntentosLogin intentos=new IntentosLogin(reloj);
        for (int i=0;i<10;i++) intentos.permitir("demo01","local");
        assertFalse(intentos.permitir("demo01","local"));
        reloj.ahora=Instant.ofEpochSecond(301);
        assertTrue(intentos.permitir("demo01","local"));
    }
    private static class Reloj extends Clock {
        Instant ahora=Instant.EPOCH;
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zona) { return this; }
        @Override public Instant instant() { return ahora; }
    }
}
