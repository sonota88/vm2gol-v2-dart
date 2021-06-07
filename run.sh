#!/bin/bash

print_project_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

export PROJECT_DIR="$(print_project_dir)"

# DART_CMD=dart
DART_CMD="docker run --rm -i -v ${PROJECT_DIR}:/root/work my:dart dart"

cat "$1" \
  | $DART_CMD lexer.dart \
  | $DART_CMD parser.dart \
  | $DART_CMD codegen.dart
