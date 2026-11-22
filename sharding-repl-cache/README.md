# sharding-repl-cache

Шардирование + репликация (по 3 узла на шард) + кеширование через Redis.

Перед запуском остановите `mongo-sharding` / `mongo-sharding-repl`, если они занимают порты `27017`–`27020`, `8080`, `6379`.

## Как запустить

Команды из папки `sharding-repl-cache`:

```shell
docker compose down
docker compose up -d
bash scripts/cluster-init.sh
bash scripts/mongo-init.sh
```

## Как проверить

### Если вы запускаете проект на локальной машине

Откройте в браузере http://localhost:8080

### Если вы запускаете проект на предоставленной виртуальной машине

Узнать белый ip виртуальной машины

```shell
curl --silent http://ifconfig.me
```

Откройте в браузере http://<ip виртуальной машины>:8080

## Доступные эндпоинты

Список доступных эндпоинтов, swagger http://<ip виртуальной машины>:8080/docs
