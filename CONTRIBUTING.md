# Contributing

## Design invariants

Изменения не должны нарушать следующие инварианты:

1. Runtime-образ задаётся immutable reference.
2. Public ingress принадлежит edge proxy; контейнер не публикует `80/443`.
3. Data plane и control plane остаются на разных портах.
4. Состояние размещается вне контейнера.
5. Кастомные плагины распространяются как OCI-артефакты.
6. Backup, preflight и smoke-test остаются воспроизводимыми.
7. Single-node ограничения явно документированы.

## Change process

- Один logical change — один pull request.
- Изменения deployment-контракта сопровождаются обновлением документации.
- Новые переменные окружения добавляются в `.env.example`, README и профильные
  документы.
- Изменения плагинов сопровождаются обновлением `wasmplugin.yaml`, если меняется
  схема конфигурации.
- Секреты, токены и приватные registry credentials не попадают в Git.

## Validation

Минимальный набор проверок:

```bash
docker compose config
./scripts/preflight.sh
bash -n scripts/*.sh
```

Для изменений плагинов:

```bash
make -C plugins/example-header build
```

Для изменений OCI-сборки:

```bash
BUILD_IN_DOCKER=1 PUSH=0 \
  ./scripts/build-plugin.sh plugins/example-header higress-plugin-example-header:test
```

## Plugin contributions

Плагин принимается при наличии:

- исходников и воспроизводимой сборки;
- `go.mod`/`go.sum` или эквивалентного lock-файла;
- описания конфигурации;
- примера `WasmPlugin`;
- ограничений по памяти и сетевым вызовам;
- стратегии отката.

## Commit style

Предпочтителен Conventional Commits:

```text
feat(compose): add resource limits
fix(backup): resolve volume by container label
docs(plugins): clarify OCI artifact contract
```

## Documentation style

Документация описывает контракты, ограничения и эксплуатационные процедуры.
Она не должна зависеть от конкретной инсталляции, домена или имени оператора.

## License

Вклад принимается на условиях Apache License 2.0.
