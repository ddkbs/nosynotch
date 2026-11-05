import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App";

const path = location.pathname.replace(/\/$/, "");
const page = path.endsWith("/docs") ? "docs" : "home";
const variant = path.startsWith("/b") ? "b" : "a";

// No StrictMode: its double mount would hand the WebGL backgrounds an already lost context.
createRoot(document.getElementById("root")!).render(<App page={page} variant={variant} />);
