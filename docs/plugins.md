# Wasm Plugin Engineering

## Модель

Higress построен на Envoy и поддерживает кастомную логику через Proxy-Wasm.
Плагин не является отдельным контейнером и не требует пересборки runtime-образа.

Production-модель:

```text
Go/Rust source
    -> plugin.wasm
    -> OCI image (scratch + /plugin.wasm)
    -> controlled registry
    -> WasmPlugin.url = oci://...
```

## Контракт артефакта

OCI-образ выполняет роль immutable distribution envelope. Он содержит ровно
один артефакт — `/plugin.wasm`. Образ не запускается как сервис.

Контракт обеспечивает:

- воспроизводимую версию плагина;
- откат по tag/digest;
- независимый supply chain;
- совместимость Docker и Kubernetes;
- отсутствие зависимости от внутренней структуры all-in-one образа.

## SDK и toolchain

Референсная реализация использует Go и TinyGo:

- `github.com/higress-group/wasm-go`;
- `github.com/tidwall/gjson`;
- TinyGo target `wasi`;
- scheduler `none`.

Референсный плагин: [`plugins/example-header`](../plugins/example-header).
Он добавляет настраиваемый request header и демонстрирует разбор конфигурации,
request-phase hook и упаковку в OCI.

## Сборка

Локальный toolchain:

```bash
make -C plugins/example-header build
```

Изолированная сборка:

```bash
BUILD_IN_DOCKER=1 \
./scripts/build-plugin.sh plugins/example-header \
  ghcr.io/ORG/higress-plugin-example-header:0.1.0
```

`Dockerfile.plugin-build` выполняет компиляцию в builder-stage, а итоговый образ
содержит только `/plugin.wasm`.

## Registry и supply chain

Production-релизы публикуются в контролируемый registry:

```bash
./scripts/build-plugin.sh plugins/example-header \
  registry.example.com/gateway/higress-plugin-example-header:0.1.0
```

Проверка опубликованного артефакта:

```bash
docker buildx imagetools inspect registry.example.com/gateway/higress-plugin-example-header:0.1.0
```

Требования:

- immutable tag или digest;
- аутентифицированный registry для приватных плагинов;
- image pull secret в Higress Console;
- регулярное сканирование артефактов;
- запрет анонимной публикации.

Для air-gapped контуров используется внутренний OCI registry. Передача raw
`plugin.wasm` по HTTP допустима только как dev-механизм: она не даёт
версионирования и целостности.

## Runtime registration

1. **Higress Console → Plugin Market → Custom Plugins**.
2. Тип: **Wasm**.
3. OCI reference: `oci://registry.example.com/gateway/plugin:0.1.0`.
4. Image pull secret для приватного registry.
5. Scope: global или конкретный route.
6. Проверка:

```bash
curl -sS -D- https://api.example.com/ -o /dev/null | grep -i x-higress-plugin
```

В standalone-режиме Console является источником истины. `wasmplugin.yaml`
используется как контракт для API-автоматизации и CI.

## Конфигурация

`spec.config` — произвольный JSON, передаваемый в `parseConfig`:

```yaml
apiVersion: extensions.higress.io/v1alpha1
kind: WasmPlugin
metadata:
  name: example-header
  namespace: higress-system
spec:
  url: oci://ghcr.io/ORG/higress-plugin-example-header:0.1.0
  phase: UNSPECIFIED_PHASE
  priority: 100
  config:
    header_name: x-higress-plugin
    header_value: example
```

## Порядок выполнения

- `priority` определяет порядок применения: большее значение — раньше.
- `phase` принимает `AUTHN`, `AUTHZ`, `STATS`, `UNSPECIFIED_PHASE`.
- Одинаковый priority у конкурирующих плагинов делает порядок неочевидным.

## Rollout и rollback

1. Собрать новый tag.
2. Опубликовать OCI-артефакт.
3. Обновить reference в Console.
4. Проверить трафик и логи gateway.
5. Для отката вернуть предыдущий tag/digest.

Перезапуск all-in-one не требуется, но применение конфигурации имеет
асинхронную задержку.

## Ограничения

- Proxy-Wasm ABI Higress, не standalone WASI.
- Таймауты обязательны для внешних вызовов в hot path.
- Размер Wasm и memory footprint контролируются.
- Секреты не логируются.
- `go.sum` фиксируется в репозитории.
- Нативные Envoy-фильтры не поддерживаются этой моделью и требуют отдельного
  форка/сборки.

## CI

Workflow `.github/workflows/plugin-image.yml` собирает плагин через
`Dockerfile.plugin-build`, публикует OCI-образ в GHCR и формирует
provenance/SBOM. В поле image указывается Docker image reference **без**
префикса `oci://`; workflow нормализует префикс, если он был передан по ошибке.
Explicit tag обязателен, `latest` отклоняется. Для ARM-host платформа меняется
на `linux/arm64`.
