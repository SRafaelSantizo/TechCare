import { QueryClient } from "@tanstack/react-query";
import { ApiError } from "../services/errors";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // No reintentar ante errores de negocio/permiso; si ante fallos de red.
      retry: (intento, error) => {
        if (error instanceof ApiError) {
          if (error.isNetwork) return intento < 2;
          return false;
        }
        return intento < 1;
      },
      staleTime: 30_000,
      refetchOnWindowFocus: false,
    },
    mutations: {
      // Las mutaciones criticas (dinero, inventario, estados) no se repiten solas.
      retry: false,
    },
  },
});
