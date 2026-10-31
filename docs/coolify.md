# Coolify Deployment Guide

## Scope

Документ описывает production-развёртывание reference architecture на
Coolify-managed Docker host. Предполагается, что Coolify владеет публичным
ingress-контуром и выпускает TLS-сертификаты.

## Deployment contract

| Параметр | Значение |
|---|---|
| Build pack | Docker Compose |
| Compose file | `/docker-compose.yml` |
| Edge proxy | Coolify-managed Traefik/Caddy |
| Data plane | `higress:8080` |
| Control plane | `higress:8001` |
| State | Named volume, `/data` |
| Public ports on host | Не публикуются |
| TLS | Edge proxy |

## Предварительные условия

- Docker Compose v2 на host.
- Не менее **2 vCPU** и **2 GB RAM** для комфортного старта all-in-one.
- Свободные `80/443` находятся под управлением Coolify.
- Для control plane предусмотрен отдельный домен.
- Registry доступен из контейнера, если используются OCI-плагины.

## Supply chain образа

Публичный registry Higress расположен в Aliyun. В зависимости от региона он
может быть медленным или недоступным. Production-инсталляциям рекомендуется
зеркалировать runtime-образ в собственный registry:

```bash
docker pull higress-registry.cn-hangzhou.cr.aliyuncs.com/higress/all-in-one:<version>
docker tag  higress-registry.cn-hangzhou.cr.aliyuncs.com/higress/all-in-one:<version> \
            registry.example.com/higress/all-in-one:<version>
docker push registry.example.com/higress/all-in-one:<version>
```

Далее фиксируется digest:

```bash
./scripts/pin-image.sh registry.example.com/higress/all-in-one:<version>
```

Coolify должен иметь credentials к приватному registry. `HIGRESS_IMAGE`
обязателен и не имеет production-значения по умолчанию.

## Ресурс в Coolify

1. Создать ресурс **Docker Compose**.
2. Подключить Git-репозиторий.
3. Указать **Docker Compose Location**: `/docker-compose.yml`.
4. Указать **Base Directory**: `/`.
5. Не включать публикацию портов через UI: ingress уже описан через `expose`.

## Environment contract

| Переменная | Обязательна | Назначение |
|---|---:|---|
| `HIGRESS_IMAGE` | да | Immutable runtime image |
| `HIGRESS_CONSOLE_ADMIN_PASSWORD` | да | Первичный пароль администратора |
| `HIGRESS_CONSOLE_OPENAPI_JWT_SECRET` | да | Подпись OpenAPI-токенов |
| `HIGRESS_CONSOLE_ADMIN_USER` | нет | Имя администратора |
| `HIGRESS_PLATFORM` | нет | Платформа образа |
| `HIGRESS_VOLUME_NAME` | нет | Имя state volume |
| `TZ` | нет | Часовой пояс |
| `JAVA_OPTS` | нет | Параметры JVM консоли |
| `HIGRESS_CPU_LIMIT` / `HIGRESS_MEM_LIMIT` | нет | Resource limits |
| `HIGRESS_CPU_RESERVATION` / `HIGRESS_MEM_RESERVATION` | нет | Reservations |
| `SERVER_FORWARD_HEADERS_STRATEGY` | нет | Forwarded headers |

Генерация секретов:

```bash
openssl rand -base64 36   # admin password
openssl rand -base64 48   # JWT secret
```

`HIGRESS_VOLUME_NAME` фиксируется до первого деплоя. Изменение имени после
инициализации создаёт новый пустой volume и требует миграции данных.

## Domain routing

Coolify создаёт отдельный proxy-router для каждого exposed port. Для двух
контуров используются magic-переменные:

```dotenv
SERVICE_FQDN_HIGRESS_8080=api.example.com
SERVICE_FQDN_HIGRESS_8001=console.example.com
```

Результат:

| Домен | Backend | Контур |
|---|---|---|
| `api.example.com` | `higress:8080` | Data plane |
| `console.example.com` | `higress:8001` | Control plane |

Ручные домены для тех же портов дублировать не следует. Если версия Coolify не
поддерживает несколько FQDN на сервис, домены задаются через UI с явным указанием
порта.

## TLS и forwarded headers

TLS терминируется на Coolify. Higress получает HTTP-трафик от edge-прокси.
`SERVER_FORWARD_HEADERS_STRATEGY=framework` обеспечивает корректные redirects и
абсолютные ссылки консоли.

Для mTLS и end-to-end TLS HTTP-роутинг недостаточен. Используется отдельный
TCP-путь, описанный в `../docker-compose.override.example.yml`. В этом сценарии
DNS, сертификаты и firewall находятся в зоне ответственности оператора.

### Real client IP

Edge-прокси добавляет `X-Forwarded-For`, но Higress по умолчанию видит адрес
прокси. Для ACL и rate-limit по клиентскому IP необходимо явно настроить
доверенные hops. Заголовкам от произвольных клиентов доверять нельзя.

## gRPC и HTTP/2

Если Coolify proxy не поддерживает HTTP/2/h2c до backend, gRPC-трафик
направляется через отдельный TCP-порт. Для HTTP-трафика достаточно стандартного
edge-роутинга.

## Первый запуск

Первый старт all-in-one занимает **1–2 минуты**: инициализируются Nacos,
controller, console и Envoy.

Проверка состояния (команды выполняются в deployment-каталоге Coolify на host):

```bash
docker compose ps
docker inspect --format '{{json .State.Health}}' \
  "$(docker compose ps -q higress)" | jq
```

Проверка доменов:

```bash
./scripts/smoke-test.sh https://api.example.com https://console.example.com
```

До добавления маршрутов ответ `404` от Higress является корректным.

## Обновление

1. Остановить сервис и создать backup state volume.
2. Проверить release notes Higress.
3. Заменить `HIGRESS_IMAGE` на новый digest.
4. Выполнить redeploy.
5. Проверить health, smoke-test и логи.
6. При необходимости откатиться на предыдущий digest.

Обновление без backup считается нарушением эксплуатационного контракта.

## Откат

Откат выполняется сменой `HIGRESS_IMAGE` на предыдущий digest и повторным
deploy. State volume не удаляется. Если новая версия изменила схему состояния,
восстановление выполняется из backup.

## Диагностика

| Симптом | Вероятная причина | Действие |
|---|---|---|
| Консоль редиректит на `http://` | Потерян `X-Forwarded-Proto` | Проверить edge proxy и `SERVER_FORWARD_HEADERS_STRATEGY` |
| Login зацикливается | Некорректный forwarded host/proto | Очистить cookies, проверить proxy headers |
| Пустая консоль после redeploy | Изменился `HIGRESS_VOLUME_NAME` | Вернуть имя volume или восстановить backup |
| Контейнер unhealthy | Медленный старт или OOM | Увеличить `start_period`/memory limit, проверить логи |
| `502` от edge proxy | Неверный backend port | Проверить `expose` и FQDN-переменные |
| Плагин не загружается | Registry недоступен или нет pull secret | Проверить egress и credentials |

## Acceptance criteria

| Критерий | Проверка |
|---|---|
| Runtime healthy | `docker compose ps` / health state |
| Control plane доступен по HTTPS | Console login page |
| Data plane отвечает | `scripts/smoke-test.sh` |
| Маршруты применяются | Тестовый route и upstream |
| State сохраняется | Redeploy без потери конфигурации |
| Backup восстанавливается | Restore на отдельном стенде |
| Секреты не в Git | `git grep` по credential patterns |
| Версия зафиксирована | `HIGRESS_IMAGE` содержит digest |

## Direct ingress

Прямая публикация портов допускается только при наличии протокольного
требования: mTLS, end-to-end TLS, gRPC или HTTP/2. В этом случае используется
`docker-compose.override.example.yml`, DNS указывает на host напрямую, а
сертификаты и firewall настраиваются оператором.
