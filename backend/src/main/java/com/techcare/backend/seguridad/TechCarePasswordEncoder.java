package com.techcare.backend.seguridad;

import org.springframework.security.crypto.password.PasswordEncoder;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/** Compatible con los hashes PBKDF2-HMAC-SHA256 existentes en 02_Datos_Prueba.sql. */
public final class TechCarePasswordEncoder implements PasswordEncoder {
    private static final int ITERACIONES=600_000;
    private final SecureRandom random=new SecureRandom();

    @Override public String encode(CharSequence rawPassword) {
        byte[] salt=new byte[16];
        random.nextBytes(salt);
        byte[] hash=derivar(rawPassword,salt,ITERACIONES);
        return "$pbkdf2-sha256$"+ITERACIONES+"$"+Base64.getEncoder().encodeToString(salt)
                +"$"+Base64.getEncoder().encodeToString(hash);
    }

    @Override public boolean matches(CharSequence rawPassword, String encodedPassword) {
        if (rawPassword==null || encodedPassword==null || rawPassword.length()>256) return false;
        try {
            String[] partes=encodedPassword.split("\\$",-1);
            if (partes.length!=5 || !partes[0].isEmpty() || !partes[1].equals("pbkdf2-sha256")) return false;
            int iteraciones=Integer.parseInt(partes[2]);
            if (iteraciones<100_000 || iteraciones>2_000_000) return false;
            byte[] salt=Base64.getDecoder().decode(partes[3]);
            byte[] esperado=Base64.getDecoder().decode(partes[4]);
            if (salt.length<16 || salt.length>64 || esperado.length!=32) return false;
            return MessageDigest.isEqual(esperado,derivar(rawPassword,salt,iteraciones));
        } catch (IllegalArgumentException ex) {
            return false;
        }
    }

    private byte[] derivar(CharSequence password, byte[] salt, int iteraciones) {
        PBEKeySpec spec=new PBEKeySpec(password.toString().toCharArray(),salt,iteraciones,256);
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } catch (GeneralSecurityException ex) {
            throw new IllegalStateException("El entorno no permite verificar PBKDF2-HMAC-SHA256.",ex);
        } finally {
            spec.clearPassword();
        }
    }
}
