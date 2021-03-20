#!/bin/bash

cat "$1" \
  | dart lexer.dart \
  | dart parser.dart \
  | dart vgcg.dart
