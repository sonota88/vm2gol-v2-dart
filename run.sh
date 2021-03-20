#!/bin/bash

cat "$1" \
  | dart lexer.dart \
  | dart vgparser.dart \
  | dart vgcg.dart
