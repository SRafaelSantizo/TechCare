import { PendingModule } from "../../components/ui/PendingModule";

export function ComprasPage() {
  return (
    <PendingModule
      modulo="Compras"
      titulo="Compras y recepcion"
      descripcion="Registrar y recibir abastecimiento de proveedores. Una compra pendiente no aumenta existencias; la recepcion se confirma de una vez."
    />
  );
}
