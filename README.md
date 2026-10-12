# Oficina — sistema de ordens de serviço

Aplicativo Flutter + backend para uma oficina mecânica: entrada do veículo, inspeção mecânica por componentes, retorno ao comercial.

## Estado atual (honesto)

| Parte | Estado |
|---|---|
| Domínio + casos de uso (backend) | implementado e **testado** |
| API HTTP (Fastify), persistência (Postgres/Prisma), storage de fotos, JWT | **não implementado** |
| App Flutter | **não implementado** |
| Testes de integração, E2E de API, testes Flutter | **não implementados** |
| `tsc --noEmit`, ESLint | **não executados** (sem acesso ao registro npm na sessão de geração) |

## Como rodar o que existe

Requer Node ≥ 22.18 (sem `npm install`: não há dependências).

```bash
cd backend
npm run lint:boundaries      # regra de dependência entre camadas
npm run test:unit            # 55 testes unitários
npm run test:unit:coverage   # exige ≥ 80% de linhas em domain/application
```

Resultado na geração: 55/55 testes passando; cobertura de linhas 99,6% (domain + application).
Verificação de sensibilidade: três regras foram quebradas de propósito (checagem de acesso à OS, validação de inspeção incompleta, transição proibida) e a suíte falhou em cada caso.

## Estrutura

```
backend/src/domain          regras puras (OS, inspeção, recomendações, perfis)
backend/src/application     casos de uso, portas e autorização
backend/test/unit           testes de domínio e de casos de uso (fakes em memória)
backend/test/support        fakes e montagem do cenário
docs/adr                    decisões de arquitetura
```

## Próximas fatias
1. Camada HTTP (Fastify) + JWT, com testes `inject`.
2. Repositórios Postgres + migrations + testes de integração (Testcontainers).
3. E2E de API (fluxos 1–4).
4. App Flutter (login, lista de OS, inspeção, comercial) + testes de widget e `integration_test`.
5. Fotos (storage S3/MinIO).
