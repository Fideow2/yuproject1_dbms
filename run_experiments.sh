#!/bin/bash






PG_CONTAINER="my-postgres"
OG_CONTAINER="opengauss-db"

DB_USER="postgres"
OG_DB_USER="gaussdb"
DB_NAME="postgres"
OG_OS_USER="omm"

PG_PASSWORD="123456"
OG_PASSWORD="Secret@123"

SQL_DIR="2_sql"
SQL_DIR_IN_CONTAINER="/tmp/sql"

RUNS=3
LOG_FILE="experiment_results.log"


> "$LOG_FILE"
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}


log "--- 准备阶段：将SQL文件复制到容器 ---"
docker exec "$PG_CONTAINER" rm -rf "$SQL_DIR_IN_CONTAINER" && docker exec "$PG_CONTAINER" mkdir -p "$SQL_DIR_IN_CONTAINER"
docker exec "$OG_CONTAINER" rm -rf "$SQL_DIR_IN_CONTAINER" && docker exec "$OG_CONTAINER" mkdir -p "$SQL_DIR_IN_CONTAINER"
docker cp "$SQL_DIR/." "$PG_CONTAINER:$SQL_DIR_IN_CONTAINER/"
docker cp "$SQL_DIR/." "$OG_CONTAINER:$SQL_DIR_IN_CONTAINER/"
log "SQL 文件已成功复制到所有容器。"


for i in $(seq 1 $RUNS); do
    log "\n\n################# 开始第 $i / $RUNS轮 JOIN 测试 #################"


    log "\n--- [测试 1.1] PostgreSQL：JOIN 查询 (无索引) ---"
    log "  > 重启容器以清空缓存并移除索引..."
    docker restart "$PG_CONTAINER" &> /dev/null; sleep 10
    docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
      psql -h localhost -U "$DB_USER" -d "$DB_NAME" \
      -c "DROP INDEX IF EXISTS idx_persons_name; DROP INDEX IF EXISTS idx_principals_person_id; DROP INDEX IF EXISTS idx_principals_movie_id;" &> /dev/null
    log "  > 执行无索引 JOIN 查询..."
    docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
      psql -h localhost -U "$DB_USER" -d "$DB_NAME" \
      -c "\timing" -f "$SQL_DIR_IN_CONTAINER/join_test.sql" | tee -a "$LOG_FILE"

    log "\n--- [测试 1.2] openGauss：JOIN 查询 (无索引) ---"
    log "  > 重启容器以清空缓存并移除索引..."
    docker restart "$OG_CONTAINER" &> /dev/null; sleep 15
    docker exec -u "$OG_OS_USER" "$OG_CONTAINER" \
      bash -l -c "gsql -d $DB_NAME -p 5432 -h localhost -U $OG_DB_USER -W \"$OG_PASSWORD\" -c 'DROP INDEX IF EXISTS idx_persons_name; DROP INDEX IF EXISTS idx_principals_person_id; DROP INDEX IF EXISTS idx_principals_movie_id;'" &> /dev/null
    log "  > 执行无索引 JOIN 查询..."
    docker exec -u "$OG_OS_USER" "$OG_CONTAINER" \
      bash -l -c '
        set -e
        SQLF='"$SQL_DIR_IN_CONTAINER"'/join_test.sql
        i=0
        current=""
        while IFS= read -r line; do
          case "$line" in
            --*) continue ;;
          esac
          current="${current}${line}"$'\n'
          if echo "$line" | grep -q ";"; then
            i=$((i+1))
            stmt_file="/tmp/og_stmt_${i}.sql"
            printf "%s" "$current" > "$stmt_file"
            start=$(date +%s%3N)
            gsql -d '"$DB_NAME"' -p 5432 -h localhost -U '"$OG_DB_USER"' -W "'"$OG_PASSWORD"'" -f "$stmt_file" > /dev/null 2>&1
            end=$(date +%s%3N)
            dur=$((end - start))
            echo "[openGauss no-index] stmt $i time: ${dur} ms"
            current=""
          fi
        done < "$SQLF"
      ' | tee -a "$LOG_FILE"



    log "\n--- [测试 2.1] PostgreSQL：JOIN 查询 (有索引) ---"
    log "  > 重启容器以清空缓存..."
    docker restart "$PG_CONTAINER" &> /dev/null; sleep 10
    log "  > 正在创建索引..."
    docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
      psql -h localhost -U "$DB_USER" -d "$DB_NAME" \
      -c "\timing" -f "$SQL_DIR_IN_CONTAINER/create_indexes_for_join.sql" | tee -a "$LOG_FILE"
    log "  > 索引创建完毕，执行有索引 JOIN 查询..."
    docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
      psql -h localhost -U "$DB_USER" -d "$DB_NAME" \
      -c "\timing" -f "$SQL_DIR_IN_CONTAINER/join_test.sql" | tee -a "$LOG_FILE"

    log "\n--- [测试 2.2] openGauss：JOIN 查询 (有索引) ---"
    log "  > 重启容器以清空缓存..."
    docker restart "$OG_CONTAINER" &> /dev/null; sleep 15
    log "  > 正在创建索引..."
    docker exec -u "$OG_OS_USER" "$OG_CONTAINER" \
      bash -l -c '
        set -e
        SQLF='"$SQL_DIR_IN_CONTAINER"'/create_indexes_for_join.sql
        i=0
        current=""
        while IFS= read -r line; do
          case "$line" in
            --*) continue ;;
          esac
          current="${current}${line}"$'\n'
          if echo "$line" | grep -q ";"; then
            i=$((i+1))
            stmt_file="/tmp/og_idx_${i}.sql"
            printf "%s" "$current" > "$stmt_file"
            start=$(date +%s%3N)
            gsql -d '"$DB_NAME"' -p 5432 -h localhost -U '"$OG_DB_USER"' -W "'"$OG_PASSWORD"'" -f "$stmt_file" > /dev/null 2>&1
            end=$(date +%s%3N)
            dur=$((end - start))
            echo "[openGauss create-index] stmt $i time: ${dur} ms"
            current=""
          fi
        done < "$SQLF"
      ' | tee -a "$LOG_FILE"
    log "  > 索引创建完毕，执行有索引 JOIN 查询..."
    docker exec -u "$OG_OS_USER" "$OG_CONTAINER" \
      bash -l -c '
        set -e
        SQLF='"$SQL_DIR_IN_CONTAINER"'/join_test.sql
        i=0
        current=""
        while IFS= read -r line; do
          case "$line" in
            --*) continue ;;
          esac
          current="${current}${line}"$'\n'
          if echo "$line" | grep -q ";"; then
            i=$((i+1))
            stmt_file="/tmp/og_stmt_${i}.sql"
            printf "%s" "$current" > "$stmt_file"
            start=$(date +%s%3N)
            gsql -d '"$DB_NAME"' -p 5432 -h localhost -U '"$OG_DB_USER"' -W "'"$OG_PASSWORD"'" -f "$stmt_file" > /dev/null 2>&1
            end=$(date +%s%3N)
            dur=$((end - start))
            echo "[openGauss with-index] stmt $i time: ${dur} ms"
            current=""
          fi
        done < "$SQLF"
      ' | tee -a "$LOG_FILE"

    log "\n--- [文件I/O对比说明] ---"
    log "  > 对于关系型JOIN操作，简单的文件I/O没有直接、高效的对应方法。"

done

log "\n\n################# 所有实验已完成 #################"
log "详细结果已保存在 $LOG_FILE 文件中。"
