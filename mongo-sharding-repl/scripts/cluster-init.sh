wait_mongo() {
  local service="$1" port="$2" i
  echo "Ждём $service:$port ..."
  for i in $(seq 1 60); do
    if docker compose exec -T "$service" mongosh --port "$port" --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Таймаут: $service:$port не отвечает" >&2
  exit 1
}

wait_primary() {
  local service="$1" port="$2" i state
  echo "Ждём PRIMARY у $service ..."
  for i in $(seq 1 60); do
    state="$(docker compose exec -T "$service" mongosh --port "$port" --quiet --eval 'rs.status().myState' 2>/dev/null | tr -d '\r')"
    if [ "$state" = "1" ]; then
      return 0
    fi
    sleep 1
  done
  echo "Таймаут: нет PRIMARY у $service:$port" >&2
  exit 1
}

wait_mongo configSrv 27017
echo "rs.initiate config_server"
docker compose exec -T configSrv mongosh --port 27017 --quiet --eval 'rs.initiate({_id:"config_server",configsvr:true,members:[{_id:0,host:"configSrv:27017"}]})' || true
wait_primary configSrv 27017

wait_mongo shard1-1 27018
wait_mongo shard1-2 27018
wait_mongo shard1-3 27018
wait_mongo shard2-1 27019
wait_mongo shard2-2 27019
wait_mongo shard2-3 27019

echo "rs.initiate shard1 (3 члена)"
docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval 'rs.initiate({_id:"shard1",members:[{_id:0,host:"shard1-1:27018"},{_id:1,host:"shard1-2:27018"},{_id:2,host:"shard1-3:27018"}]})' || true

echo "rs.initiate shard2 (3 члена)"
docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval 'rs.initiate({_id:"shard2",members:[{_id:0,host:"shard2-1:27019"},{_id:1,host:"shard2-2:27019"},{_id:2,host:"shard2-3:27019"}]})' || true

wait_primary shard1-1 27018
wait_primary shard2-1 27019

echo "Перезапуск mongos_router"
docker compose restart mongos_router
wait_mongo mongos_router 27020

echo "addShard + shardCollection"
if ! docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval '
db.adminCommand({addShard:"shard1/shard1-1:27018", maxTimeMS:30000});
db.adminCommand({addShard:"shard2/shard2-1:27019", maxTimeMS:30000});
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
'; then
  echo "addShard не удался. Останови другой стек и пересоздай контейнеры:" >&2
  echo "  docker compose down && docker compose up -d && bash scripts/cluster-init.sh" >&2
  exit 1
fi

shards_count="$(docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval 'db.adminCommand({listShards:1}).shards.length' | tr -d '\r')"
if [ "$shards_count" != "2" ]; then
  echo "Ошибка: ожидалось 2 шарда, сейчас: $shards_count" >&2
  exit 1
fi

echo "Готово: шардов $shards_count, у каждого по 3 реплики"
