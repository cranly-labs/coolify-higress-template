# Security Policy

## Supported versions

| Канал | Поддержка |
|---|---|
| `main` | Active |
| Latest tagged release | Active |
| Предыдущие releases | Best effort |

Runtime-версия Higress фиксируется оператором через `HIGRESS_IMAGE`. Поддержка
конкретной версии Higress определяется upstream-политикой проекта Higress.

## Reporting a vulnerability

Уязвимости не публикуются в открытых issue. Используется GitHub private
vulnerability reporting для репозитория.

В отчёте указываются:

- затронутый компонент и версия;
- вектор эксплуатации;
- минимальный reproducer;
- оценка влияния;
- предложение по исправлению, если доступно.

Целевые сроки реакции:

| Этап | Цель |
|---|---|
| Подтверждение получения | 3 рабочих дня |
| Первичный triage | 10 рабочих дней |
| План исправления | по результатам triage |

Сроки являются целями, а не гарантией SLA.

## Security model

**Edge.** Публичный ingress и TLS находятся на Coolify proxy. Runtime-контейнер
не публикует порты на host.

**Control plane.** Higress Console не предназначен для открытого интернета.
Минимальная защита — сильный пароль; целевая — VPN, IP allowlist или
identity-aware proxy.

**Secrets.** Пароли и JWT-секреты хранятся в Coolify environment variables.
`.env` не коммитится. Доступ к Docker socket приравнивается к доступу к секретам.

**Supply chain.** Runtime-образ фиксируется по digest. Плагины публикуются в
контролируемый OCI registry и подключаются по immutable reference. Приватные
registry используют image pull secret.

**Plugin trust.** Wasm-плагин исполняется в gateway и должен рассматриваться как
доверенный код. Код плагинов проходит review, а артефакты — сканирование.

## Hardening baseline

- Control plane за VPN/IP allowlist.
- Уникальные секреты для каждой инсталляции.
- Регулярная ротация credentials.
- Pinned runtime digest.
- Ограниченный egress.
- Backup перед обновлением.
- Мониторинг OOM, `5xx`, health и диска.
- Отдельный registry namespace для плагинов.
- Запрет анонимной публикации OCI-артефактов.

## Out of scope

- Защита host, если у атакующего уже есть root или Docker socket.
- Уязвимости upstream Higress, Envoy, Nacos и Java runtime, не вызванные
  конфигурацией этого репозитория.
- Компрометация внешнего registry или CI-системы.
- DDoS-защита на уровне сети.
