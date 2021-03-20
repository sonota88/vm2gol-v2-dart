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

  cat ${TEST_DIR}/${nn}.vg.txt | dart lexer.dart > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    return
  fi

  cat $temp_tokens_file | dart parser.dart > $temp_vgt_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parse"
    return
  fi

  cat $temp_vgt_file | dart codegen.dart > $temp_vga_file
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

test_compile() {
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
}

# --------------------------------

test_all() {
  # echo "==== json ===="
  # test_json
  # if [ $? -ne 0 ]; then
  #   ERRS="${ERRS},${nn}_json"
  #   return
  # fi

  # echo "==== lex ===="
  # test_lex
  # if [ $? -ne 0 ]; then
  #   ERRS="${ERRS},${nn}_lex"
  #   return
  # fi

  # echo "==== parse ===="
  # test_parse
  # if [ $? -ne 0 ]; then
  #   ERRS="${ERRS},${nn}_parser"
  #   return
  # fi

  echo "==== compile ===="
  test_compile
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_compile"
    return
  fi
}
# --------------------------------

mkdir -p z_tmp

cmd="$1"; shift
case $cmd in
  compile | c*)  #task: Run compile tests
    test_compile "$@"
    # postproc "compile"
    ;;

  all | a*)      #task: Run all tests
    test_all
    # postproc "all"
    ;;

  *)
    echo "Tasks:"
    grep '#task: ' $0 | grep -v grep
    ;;

esac

