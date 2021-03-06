import 'dart:io';
import 'dart:convert';

import 'lib/utils.dart';

parseJson(String json) {
  final decoder = new JsonDecoder();
  return decoder.convert(json);
}

// --------------------------------

List getRest(List xs) {
  return xs.sublist(1);
}

// --------------------------------

asmPrologue() {
  print("  push bp");
  print("  cp sp bp");
}

asmEpilogue() {
  print("  cp bp sp");
  print("  pop bp");
}

// --------------------------------

var globalLabelId = 0;

fnArgDisp(fnArgNames, fnArgName) {
  final i = fnArgNames.indexOf(fnArgName);
  return i + 2;
}

lvarDisp(lvarNames, lvarName) {
  final i = lvarNames.indexOf(lvarName);
  return -(i + 1);
}

indirection(base, disp) {
  return "[${base}:${disp}]";
}

_genExpr_add() {
  print("  pop reg_b");
  print("  pop reg_a");
  print("  add_ab");
}

_genExpr_mult() {
  print("  pop reg_b");
  print("  pop reg_a");
  print("  mult_ab");
}

_genExpr_eq() {
  globalLabelId++;
  final labelId = globalLabelId;

  final labelEnd = "end_eq_${labelId}";
  final labelThen = "then_${labelId}";

  print("  pop reg_b");
  print("  pop reg_a");

  print("  compare");
  print("  jump_eq ${labelThen}");

  // else
  print("  cp 0 reg_a");
  print("  jump ${labelEnd}");

  // then
  print("label ${labelThen}");
  print("  cp 1 reg_a");

  print("label ${labelEnd}");
}

_genExpr_neq() {
  globalLabelId++;
  final labelId = globalLabelId;

  final labelEnd = "end_neq_${labelId}";
  final labelThen = "then_${labelId}";

  print("  pop reg_b");
  print("  pop reg_a");

  print("  compare");
  print("  jump_eq ${labelThen}");

  // else
  print("  cp 1 reg_a");
  print("  jump ${labelEnd}");

  // then
  print("label ${labelThen}");
  print("  cp 0 reg_a");

  print("label ${labelEnd}");
}

_genExpr_binary(fnArgNames, lvarNames, expr) {
  final op = expr[0];
  final args = getRest(expr);

  final argL = args[0];
  final argR = args[1];

  genExpr(fnArgNames, lvarNames, argL);
  print("  push reg_a");
  genExpr(fnArgNames, lvarNames, argR);
  print("  push reg_a");

  if (op == "+") {
    _genExpr_add();
  } else if (op == "*") {
    _genExpr_mult();
  } else if (op == "eq") {
    _genExpr_eq();
  } else if (op == "neq") {
    _genExpr_neq();
  } else {
    throw notYetImpl([ op ]);
  }
}

genExpr(fnArgNames, lvarNames, expr) {
  if (expr is int) {
    print("  cp ${expr} reg_a");
  } else if (expr is String) {
    if (fnArgNames.contains(expr)) {
      final cpSrc = indirection("bp", fnArgDisp(fnArgNames, expr));
      print("  cp ${cpSrc} reg_a");
    } else if (lvarNames.contains(expr)) {
      final cpSrc = indirection("bp", lvarDisp(lvarNames, expr));
      print("  cp ${cpSrc} reg_a");
    } else {
      throw notYetImpl([ expr ]);
    }
  } else if (expr is List) {
    _genExpr_binary(fnArgNames, lvarNames, expr);
  } else {
    throw notYetImpl([ expr ]);
  }
}

genVar(fnArgNames, lvarNames, stmtRest) {
  print("  sub_sp 1");

  if (stmtRest.length == 2) {
    genSet(fnArgNames, lvarNames, stmtRest);
  }
}

genCall(fnArgNames, lvarNames, stmtRest) {
  final fnName = stmtRest[0];
  final fnArgs = getRest(stmtRest);

  fnArgs.reversed.forEach((fnArg){
      genExpr(
        fnArgNames, lvarNames, fnArg
      );
      print("  push reg_a");
  });

  genVmComment("call  ${fnName}");
  print("  call ${fnName}");
  print("  add_sp ${fnArgs.length}");
}

genCallSet(fnArgNames, lvarNames, stmtRest) {
  final lvarName = stmtRest[0];
  final funcall = stmtRest[1];

  genCall(fnArgNames, lvarNames, funcall);

  final cpDest = indirection("bp", lvarDisp(lvarNames, lvarName));
  print("  cp reg_a ${cpDest}");
}

genSet(fnArgNames, lvarNames, rest) {
  final dest = rest[0];
  final expr = rest[1];

  genExpr(fnArgNames, lvarNames, expr);

  final cpDest = indirection("bp", lvarDisp(lvarNames, dest));
  print("  cp reg_a ${cpDest}");
}

genReturn(lvarNames, stmtRest) {
  final retval = stmtRest[0];
  genExpr([], lvarNames, retval);
}

genWhile(fnArgNames, lvarNames, rest) {
  final condExp = rest[0];
  final body = rest[1];

  globalLabelId++;
  final labelId = globalLabelId;

  final labelBegin = "while_${labelId}";
  final labelEnd = "end_while_${labelId}";
  final labelTrue = "true_${labelId}";

  print("");

  // ループの先頭
  print("label ${labelBegin}");

  // 条件の評価
  genExpr(fnArgNames, lvarNames, condExp);

  // 比較対象の値（真）をセット
  print("  cp 1 reg_b");
  print("  compare");

  // true の場合ループの本体を実行
  print("  jump_eq ${labelTrue}");

  // false の場合ループを抜ける
  print("  jump ${labelEnd}");

  print("label ${labelTrue}");

  // ループの本体
  genStmts(fnArgNames, lvarNames, body);

  // ループの先頭に戻る
  print("  jump ${labelBegin}");

  print("label ${labelEnd}");
  print("");
}

genCase(fnArgNames, lvarNames, whenClauses) {
  globalLabelId++;
  final labelId = globalLabelId;

  final labelEnd = "end_case_${labelId}";
  final labelWhenHead = "when_${labelId}";
  final labelEndWhenHead = "end_when_${labelId}";

  var whenIdx = -1;

  whenClauses.forEach((whenClause){
      whenIdx++;

      final cond = whenClause[0];
      final rest = getRest(whenClause);

      final condRest = getRest(cond);

      print("  # 条件 ${labelId}_${whenIdx}: ${inspect(cond)}");

      genExpr(fnArgNames, lvarNames, cond);

      print("  cp 1 reg_b");

      print("  compare");
      print("  jump_eq ${labelWhenHead}_${whenIdx}");
      print("  jump ${labelEndWhenHead}_${whenIdx}");

      print("label ${labelWhenHead}_${whenIdx}");

      genStmts(fnArgNames, lvarNames, rest);

      print("  jump ${labelEnd}");

      print("label ${labelEndWhenHead}_${whenIdx}");
  });

  print("label end_case_${labelId}");
}

genVmComment(comment) {
  print("  _cmt " + comment.replaceAll(" ", "~"));
}

genStmt(fnArgNames, lvarNames, stmt) {
  final stmtHead = stmt[0];
  final stmtRest = getRest(stmt);

  if (stmtHead == "call") {
    genCall(fnArgNames, lvarNames, stmtRest);
  } else if (stmtHead == "call_set") {
    genCallSet(fnArgNames, lvarNames, stmtRest);
  } else if (stmtHead == "set") {
    genSet(fnArgNames, lvarNames, stmtRest);
  } else if (stmtHead == "return") {
    genReturn(lvarNames, stmtRest);
  } else if (stmtHead == "while") {
    genWhile(fnArgNames, lvarNames, stmtRest);
  } else if (stmtHead == "case") {
    genCase(fnArgNames, lvarNames, stmtRest);
  } else if (stmtHead == "_cmt") {
    genVmComment(stmtRest[0]);
  } else {
    throw notYetImpl([ stmtHead ]);
  }
}

genStmts(fnArgNames, lvarNames, stmts) {
  var stmtHead;
  var stmtRest;

  stmts.forEach((stmt){
      genStmt(fnArgNames, lvarNames, stmt);
  });
}

genFuncDef(rest) {
  final fnName = rest[0];
  final fnArgNames = rest[1];
  final body = rest[2];

  print("");
  print("label " + fnName);
  asmPrologue();

  print("");
  print("  # 関数の処理本体");

  final lvarNames = [];

  body.forEach((stmt){
      final stmtRest = getRest(stmt);
      if (stmt[0] == "var") {
        lvarNames.add(stmtRest[0]);
        genVar(fnArgNames, lvarNames, stmtRest);
      } else {
        genStmt(fnArgNames, lvarNames, stmt);
      }
  });

  print("");
  asmEpilogue();
  print("  ret");
}

genTopStmts(rest) {
  rest.forEach((stmt){
      final stmtHead = stmt[0];
      final stmtRest = getRest(stmt);

      if (stmtHead == "func") {
        genFuncDef(stmtRest);
      } else {
        throw notYetImpl([stmtHead]);
      }
  });
}

genBuiltinSetVram() {
  print("");
  print("label set_vram");
  asmPrologue();
  print("  set_vram [bp:2] [bp:3]"); // vram_addr value
  asmEpilogue();
  print("  ret");
}

genBuiltinGetVram() {
  print("");
  print("label get_vram");
  asmPrologue();
  print("  get_vram [bp:2] reg_a"); // vram_addr dest
  asmEpilogue();
  print("  ret");
}

codegen(tree) {
  print("  call main");
  print("  exit");

  final head = tree[0];
  final rest = getRest(tree);

  genTopStmts(rest);

  print("#>builtins");
  genBuiltinSetVram();
  genBuiltinGetVram();
  print("#<builtins");
}

main(){
  final src = readAll();
  final tree = parseJson(src);

  try {
    codegen(tree);
  } catch(e, s) {
    puts_e(e);
    puts_e(s);
    throw e;
  }
}
