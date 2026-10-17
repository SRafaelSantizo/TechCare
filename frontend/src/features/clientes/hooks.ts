import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { clientesApi, clientesKeys } from "../../services/clientes";
import type { Cliente, ClienteDatos } from "../../types/api";

export function useClientes() {
  return useQuery({
    queryKey: clientesKeys.list(),
    queryFn: ({ signal }) => clientesApi.listar(signal),
  });
}

export function useCliente(id: number | null) {
  return useQuery({
    queryKey: clientesKeys.detail(id ?? 0),
    queryFn: ({ signal }) => clientesApi.consultar(id as number, signal),
    enabled: id !== null && id > 0,
  });
}

export function useCrearCliente() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (datos: ClienteDatos) => clientesApi.crear(datos),
    onSuccess: (creado: Cliente) => {
      qc.invalidateQueries({ queryKey: clientesKeys.list() });
      qc.setQueryData(clientesKeys.detail(creado.ClienteID), creado);
    },
  });
}

export function useActualizarCliente() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, datos }: { id: number; datos: ClienteDatos }) => clientesApi.actualizar(id, datos),
    onSuccess: (actualizado: Cliente) => {
      qc.invalidateQueries({ queryKey: clientesKeys.list() });
      qc.setQueryData(clientesKeys.detail(actualizado.ClienteID), actualizado);
    },
  });
}
