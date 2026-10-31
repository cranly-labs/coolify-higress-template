# Higress Wasm Plugin Kit

Инженерный набор для разработки, сборки и публикации кастомных Proxy-Wasm
плагинов Higress.

## Контракт артефакта

Плагин распространяется как OCI-образ, содержащий ровно один файл
`/plugin.wasm`. Образ не является runnable-сервисом: Higress использует его как
immutable distribution envelope.

```text
source -> plugin.wasm -> OCI image -> registry -> WasmPlugin
```

Такой контракт отделяет lifecycle плагина от lifecycle gateway и обеспечивает
воспроизводимый откат по digest.

## Структура

```text
plugins/
├── Dockerfile.plugin          # Упаковка готового plugin.wasm
├── Dockerfile.plugin-build    # Сборка и упаковка внутри Docker
└── example-header/            # Референсный Go-плагин
    ├── main.go
    ├── go.mod
    ├── Makefile
    └── wasmplugin.yaml        # Референсный WasmPlugin manifest

scripts/build-plugin.sh        # Build + publish pipeline
```

## Референсный плагин

`example-header` добавляет настраиваемый request header. Он намеренно минимален
и демонстрирует полный контракт: разбор конфигурации, request-phase hook и
упаковку в OCI.

### Локальная сборка

Требования: Go, TinyGo, Docker Buildx.

```bash
make -C plugins/example-header build
```

Результат: `plugins/example-header/plugin.wasm`.

### Изолированная сборка

Если локальный toolchain не используется:

```bash
BUILD_IN_DOCKER=1 \
./scripts/build-plugin.sh plugins/example-header \
  ghcr.io/ORG/higress-plugin-example-header:0.1.0
```

`Dockerfile.plugin-build` выполняет сборку в builder-stage и публикует только
scratch-артефакт.

### Публикация

```bash
./scripts/build-plugin.sh plugins/example-header \
  ghcr.io/ORG/higress-plugin-example-header:0.1.0
```

Production-релизы должны использовать immutable tag или digest.

## Runtime registration

1. Открыть **Higress Console → Plugin Market → Custom Plugins**.
2. Создать плагин типа **Wasm**.
3. Указать OCI reference: `oci://ghcr.io/ORG/higress-plugin-example-header:0.1.0`.
4. Для приватного registry настроить image pull secret.
5. Применить плагин к route или global scope.
6. Проверить результат:

```bash
curl -sS -D- https://api.example.com/ -o /dev/null | grep -i x-higress-plugin
```

В standalone-режиме Console является источником истины. `wasmplugin.yaml`
предназначен для API-автоматизации и как контракт конфигурации.

## Инженерные ограничения

- Плагин компилируется под Proxy-Wasm ABI Higress, а не как standalone WASI.
- Сетевые вызовы в hot path обязаны иметь таймауты.
- Размер Wasm и потребление памяти должны быть ограничены.
- Секреты и токены не попадают в логи.
- `go.sum` фиксируется в репозитории после первого `go mod tidy`.
- Приватный registry предпочтительнее анонимного доступа.

Подробный процесс: [../docs/plugins.md](../docs/plugins.md).
