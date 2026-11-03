# EZE Viabilidade

Sistema de estudos de viabilidade financeira imobiliária da EZE Arquitetura e Gestão.

- `index.html` — o sistema inteiro (página única). Publicado pela Vercel, sem etapa de build.
- `supabase/schema.sql` — estrutura do banco e regras de acesso. Rodar uma vez no SQL Editor do Supabase.

## Como funciona o acesso

- Só entra quem tem o e-mail liberado na tela **Acessos** (admin).
- No primeiro acesso a pessoa cria a própria senha.
- Tipos: **Admin** (tudo + acessos), **Editor** (cria e edita), **Leitor** (só vê e exporta).
- Link público sem login: `/#publico` mostra apenas os estudos marcados como públicos.

## Configuração

No topo do script em `index.html`:

```js
const SUPABASE_URL = 'https://xxxx.supabase.co';
const SUPABASE_ANON_KEY = 'chave anon public';
```

A chave anon é pública por natureza; a proteção dos dados é feita pelas regras do banco (`schema.sql`).
