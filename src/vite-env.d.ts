/// <reference types="vite/client" />

// `window.electronAPI` is declared once, in ./types/electron.d.ts. Two global
// declarations of the same property don't merge — one silently wins — which
// is how calls to a real bridge method ended up failing to typecheck.
