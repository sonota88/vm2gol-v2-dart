#!/bin/bash

cat "$1" \
  | dart vgtokenizer.dart \
  | dart vgparser.dart \
  | dart vgcg.dart
