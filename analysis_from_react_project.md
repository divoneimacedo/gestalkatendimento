# Análise rápida do projeto React enviado

O ZIP contém um projeto Next.js 13 chamado `plataforma-gestalk-web`.

Principais dependências encontradas:

- `next` 13.5.4
- `react` 18
- `@videosdk.live/react-sdk`
- `socket.io-client`
- `axios`
- `@tanstack/react-query`
- `react-toastify`
- `sweetalert2`
- `@material-ui/core`
- `tailwindcss`
- `OneSignal`

Arquivos importantes encontrados:

- `src/app/[slug]/queue/page.tsx`: fila de chamadas com polling em `/calls/waiting` ou `/calls/waiting/:slug`.
- `src/app/services/apiClient.ts`: cliente Axios com `Authorization` e `X-Company-Slug`.
- `src/app/services/apiVideo.ts`: token/criação/validação de sala VideoSDK.
- `src/app/components/MeetingContainer/*`: componentes da chamada no React.
- `src/app/context/notification.context.tsx`: lógica de notificação/som.

Endpoints usados na tela de fila:

- `GET /calls/waiting`
- `GET /calls/waiting/:slug`
- `PATCH /calls/ongoing/:id`
- `DELETE /calls/cancel/:id`

Modelo de fila inferido:

```ts
type Queue = {
  id: string
  status: string
  caller: string
  protocol: string
  channelName: string
  serviceTypeName?: string
  serviceTypePriority?: number
  createdAt: string
  waitingTime: string
  attendant?: string
}
```
