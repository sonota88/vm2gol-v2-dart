#!/bin/bash

print_project_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

export PROJECT_DIR="$(print_project_dir)"
export TEST_DIR="${PROJECT_DIR}/test"
export TEMP_DIR="${PROJECT_DIR}/z_tmp"

ERRS=""

test_nn() {
  local nn="$1"; shift

  local temp_tokens_file="${TEMP_DIR}/test.tokens.txt"
  local temp_vgt_file="${TEMP_DIR}/test.vgt.json"
  local temp_vga_file="${TEMP_DIR}/test.vga.txt"

  echo "test_${nn}"

  local exp_vga_file="${TEST_DIR}/exp_${nn}.vga.txt"

  cat ${TEST_DIR}/${nn}.vg.txt | dart vgtokenizer.dart > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_tokenize"
    return
  fi

  cat $temp_tokens_file | dart vgparser.dart > $temp_vgt_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parse"
    return
  fi

  cat $temp_vgt_file | dart vgcg.dart > $temp_vga_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_codegen"
    return
  fi

  ruby test/diff.rb $exp_vga_file $temp_vga_file
  if [ $? -ne 0 ]; then
    # meld $exp_vga_file $temp_vga_file &

    ERRS="${ERRS},${nn}_diff"
    return
  fi
}

# --------------------------------

mkdir -p z_tmp

ns=

if [ $# -eq 1 ]; then
  ns="$1"
else
  ns="$(seq 1 16)"
fi

for n in $ns; do
  test_nn $(printf "%02d" $n)
done

if [ "$ERRS" = "" ]; then
  echo "ok"
else
  echo "----"
  echo "FAILED: ${ERRS}"
fi
