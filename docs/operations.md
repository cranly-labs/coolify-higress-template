# Operations Runbook

## Ownership

Эксплуатационная команда отвечает за:

- доступность edge-контура и TLS;
- backup и восстановление state volume;
- обновление runtime-образа;
- ротацию секретов;
- контроль registry и supply chain плагинов;
- мониторинг ресурсов и инциденты.

Репозиторий задаёт контракт развёртывания, но не заменяет операционную
ответственность.

## State model

Состояние Higress размещается в named volume, по умолчанию `higress-data`.
Volume содержит данные Nacos и консоли. Пересоздание контейнера не должно
затрагивать state.

Имя volume задаётся через `HIGRESS_VOLUME_NAME` и не меняется после первой
инициализации без миграции.

## Backup

Backup выполняется с остановкой сервиса для консистентного снимка:

```bash
docker compose stop higress
./scripts/backup.sh
docker compose start higress
```

Архив сохраняется в `backups/`. Копии должны храниться вне host. Восстановление
регулярно проверяется на отдельном стенде.

## Restore

```bash
docker compose down

docker run --rm \
  -v "${HIGRESS_VOLUME_NAME:-higress-data}:/data" \
  -v "$PWD/backups:/backup" \
  alpine:3.20 \
  sh -c 'find /data -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar xzf /backup/<file>.tar.gz -C /data'

docker compose up -d
```

Перед удалением содержимого volume необходимо убедиться в правильности имени и
наличии проверенной копии.

## Recovery objectives

| Objective | Definition |
|---|---|
| RPO | Последний проверенный backup state volume |
| RTO | Время восстановления volume и возврата runtime в healthy state; измеряется на стенде |

Конкретные значения RPO/RTO утверждаются эксплуатационной командой и зависят от
частоты backup и размера state.

## Upgrade

1. Backup.
2. Проверить release notes Higress.
3. Зафиксировать новый digest.
4. Обновить `HIGRESS_IMAGE`.
5. Выполнить redeploy.
6. Проверить health, smoke-test, логи и ключевые маршруты.
7. При отклонении — откатить digest.

`latest` не используется: он делает состояние системы неопределённым и
усложняет откат.

## Observability

Минимальный набор:

- health state контейнера;
- CPU, memory, disk;
- OOM events;
- `5xx` на data plane;
- ошибки конфигурации в логах;
- latency и error rate ключевых маршрутов.

Envoy admin и metrics не публикуются в интернет. Для Prometheus scraping
используется внутренняя сеть или отдельный защищённый контур.

## Incident playbook

| Сценарий | Действие |
|---|---|
| Контейнер unhealthy | Проверить logs, memory, disk, `start_period` |
| OOM | Увеличить memory limit, проверить `JAVA_OPTS` |
| Пустая консоль | Проверить volume name и restore |
| `502` на edge | Проверить backend port и FQDN mapping |
| Плагин не применяется | Проверить OCI reference, registry access, pull secret |
| Рост `5xx` после релиза | Откатить digest, проверить конфигурацию маршрутов |
| Потеря TLS | Проверить edge proxy и DNS |

## Security operations

- Control plane за VPN, IP allowlist или identity-aware proxy.
- Сильный admin password и уникальный JWT secret.
- Ротация `HIGRESS_CONSOLE_OPENAPI_JWT_SECRET` инвалидирует выданные API-токены.
- Смена `HIGRESS_CONSOLE_ADMIN_PASSWORD` после инициализации выполняется в UI.
- Секреты хранятся только в Coolify environment variables.
- Docker socket доступен только доверенным операторам.
- Registry плагинов контролируется и сканируется.
- Egress ограничивается известными upstream и registry.

## Известные ограничения

- Нет HA control plane.
- Нет автоматического rolling-update.
- Нет встроенного backup произвольных Docker volumes в Coolify.
- All-in-one не является StatefulSet и не воспроизводит поведение Kubernetes.
- При росте требований к доступности выполняется миграция в Kubernetes.
