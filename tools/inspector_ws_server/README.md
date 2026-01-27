# Inspector WebSocket Server

Servidor Node para receber os boxes do Inspector Flutter via WebSocket e desenhar em um viewer web.

## Como rodar

```bash
npm install
npm start
```

Abra no navegador: http://localhost:7071

## Configuracao no Flutter

- Informe a URL do WebSocket no app (ex.: `ws://10.0.2.2:7071` no emulador Android).
- Ative o toggle "Enviar boxes".

## Variaveis

- `PORT` (default 7071)
- `HOST` (default 0.0.0.0)
