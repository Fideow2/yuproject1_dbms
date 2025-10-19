#!/bin/bash

PG_CONTAINER="my-postgres"
OG_CONTAINER="opengauss-db"

DB_USER="postgres"
OG_DB_USER="gaussdb"
DB_NAME="postgres"
OG_OS_USER="omm"

PG_PASSWORD="123456"
OG_PASSWORD="Secret@123"

KEYWORD_SQL_FILE="keyword_search_test.sql"
SQL_DIR="2_sql"
SQL_DIR_IN_CONTAINER="/tmp/sql"

RUNS=3
LOG_FILE="keyword_search_results.log"

> "$LOG_FILE"
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log "--- 准备阶段：将关键词搜索SQL文件复制到容器 ---"
docker exec "$PG_CONTAINER" mkdir -p "$SQL_DIR_IN_CONTAINER"
docker exec "$OG_CONTAINER" mkdir -p "$SQL_DIR_IN_CONTAINER"

docker cp "$SQL_DIR/$KEYWORD_SQL_FILE" "$PG_CONTAINER:$SQL_DIR_IN_CONTAINER/"
docker cp "$SQL_DIR/$KEYWORD_SQL_FILE" "$OG_CONTAINER:$SQL_DIR_IN_CONTAINER/"
log "SQL 文件 '$KEYWORD_SQL_FILE' 已成功复制到所有容器。"

for i in $(seq 1 $RUNS); do
    log "\n\n################# 开始第 $i / $RUNS 轮关键词搜索测试 #################"

    log "\n--- [测试 1] PostgreSQL：关键词搜索 ---"
    log "  > 重启容器以清空缓存..."
    docker restart "$PG_CONTAINER" &> /dev/null; sleep 10
    log "  > 执行关键词搜索查询..."
    docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER" \
      psql -h localhost -U "$DB_USER" -d "$DB_NAME" \
      -c "\timing" -f "$SQL_DIR_IN_CONTAINER/$KEYWORD_SQL_FILE" | tee -a "$LOG_FILE"

    log "\n--- [测试 2] openGauss：关键词搜索 ---"
    log "  > 重启容器以清空缓存..."
    docker restart "$OG_CONTAINER" &> /dev/null; sleep 15
    log "  > 执行关键词搜索查询..."
    docker exec -u "$OG_OS_USER" "$OG_CONTAINER" \
      bash -l -c '
        set -e
        SQLF="'"$SQL_DIR_IN_CONTAINER"'/'"$KEYWORD_SQL_FILE"'"
        i=0
        current=""
        while IFS= read -r line; do
          case "$line" in
            --*) continue ;;
          esac
          current="${current}${line}"$'\n'
          if echo "$line" | grep -q ";"; then
            i=$((i+1))
            stmt_file="/tmp/og_keyword_stmt_${i}.sql"
            printf "%s" "$current" > "$stmt_file"

            start=$(date +%s%3N)
            gsql -d '"$DB_NAME"' -p 5432 -h localhost -U '"$OG_DB_USER"' -W "'$OG_PASSWORD'" -f "$stmt_file"
            end=$(date +%s%3N)

            dur=$((end - start))
            echo "[openGauss keyword-search] stmt $i time: ${dur} ms"
            current=""
          fi
        done < "$SQLF"
      ' | tee -a "$LOG_FILE"
done

log "\n\n################# 关键词搜索实验已完成 #################"
log "详细结果已保存在 $LOG_FILE 文件中。"
log "现在您可以根据此文件的输出，计算三次运行的平均值来填充报告中的 [TBD] 部分。"
