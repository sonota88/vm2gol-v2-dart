#!/bin/bash

cat "$1" \
  | dart lexer.dart \
  | dart parser.dart \
  | dart codegen.dart
