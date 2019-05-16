#!/bin/bash

# main関数 {{{

main() {
  local sub_cmd=$1

  if [ -z "$sub_cmd" ]; then
    err "第一引数は必須です [ start | stop | clear ]"
    return 1
  fi

  local lock_file=lint.lock

  case "$sub_cmd" in
    start)
      info "textlintを開始"
      while true; do
        if [ -e "$lock_file" ]; then
          main clear
          info "textlintを終了"
          return 0
        fi
        docker-compose up
        sleep 5
      done
      ;;

    stop)
      info "textlintを停止するファイルを配置"
      touch "$lock_file"
      return 0
      ;;

    clear)
      info "textlintを停止するファイルを削除"
      rm "$lock_file"
      return 0
      ;;

    *)
      err "不正な第一引数です sub_cmd = $sub_cmd"
      return 2
      ;;
  esac
}

#}}}

# ユーティリティ関数 {{{

readonly COLOR_GREEN="\x1b[32m"
readonly COLOR_RED="\x1b[31m"
readonly COLOR_RESET="\x1b[m"

info() {
  echo -e "$COLOR_GREEN[INFO]$COLOR_RESET $1" 2>&1
}

err() {
  echo -e "$COLOR_RED[ERR]$COLOR_RESET $1" 2>&1
}

#}}}

main ${1+"$@"}

readonly RET=$?

if [ "$RET" -eq 0 ]; then
  info "スクリプト正常終了 RET=$RET"
  exit $RET
else
  err "スクリプト異常終了 RET=$RET"
  exit $RET
fi
