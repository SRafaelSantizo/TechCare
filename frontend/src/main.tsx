import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { QueryClientProvider } from "@tanstack/react-query";
import App from "./App";
import { queryClient } from "./app/queryClient";
import { SessionProvider } from "./app/session";
import "./styles/tokens.css";
import "./styles/global.css";

const contenedor = document.getElementById("root");
if (!contenedor) {
  throw new Error("No se encontro el elemento #root.");
}

createRoot(contenedor).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </SessionProvider>
    </QueryClientProvider>
  </StrictMode>,
);
