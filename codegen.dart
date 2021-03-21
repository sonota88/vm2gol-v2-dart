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

var globalLabelId = 0;

toFnArgRef(fnArgNames, fnArgName) {
  final i = fnArgNames.indexOf(fnArgName);
  return "[bp+${ i + 2 }]";
}

toLvarRef(lvarNames, lvarName) {
  final i = lvarNames.indexOf(lvarName);
  return "[bp-${ i + 1 }]";
}

List _genExpr_push(fnArgNames, lvarNames, val) {
  var alines = [];

  var pushArg;

  if (val is int) {
    pushArg = val;
  } else if (val is String) {
    if (fnArgNames.contains(val)) {
      pushArg = toFnArgRef(fnArgNames, val);
    } else if (lvarNames.contains(val)) {
      pushArg = toLvarRef(lvarNames, val);
    } else {
      throw notYetImpl([ val ]);
    }
  } else if (val is List) {
    alines += genExpr(fnArgNames, lvarNames, val);
    pushArg = "reg_a";
  } else {
    throw notYetImpl([ val ]);
  }

  alines.add("  push ${pushArg}");

  return alines;
}

List _genExpr_add() {
  var alines = [];

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");
  alines.add("  add_ab");

  return alines;
}

List _genExpr_mult() {
  var alines = [];

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");
  alines.add("  mult_ab");

  return alines;
}

List _genExpr_eq() {
  final alines = [];

  globalLabelId++;
  final labelId = globalLabelId;

  final labelEnd = "end_eq_${labelId}";
  final labelThen = "then_${labelId}";

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");

  alines.add("  compare");
  alines.add("  jump_eq ${labelThen}");

  // else
  alines.add("  set_reg_a 0");
  alines.add("  jump ${labelEnd}");

  // then
  alines.add("label ${labelThen}");
  alines.add("  set_reg_a 1");

  alines.add("label ${labelEnd}");

  return alines;
}

List _genExpr_neq() {
  final alines = [];

  globalLabelId++;
  final labelId = globalLabelId;

  final labelEnd = "end_neq_${labelId}";
  final labelThen = "then_${labelId}";

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");

  alines.add("  compare");
  alines.add("  jump_eq ${labelThen}");

  // else
  alines.add("  set_reg_a 1");
  alines.add("  jump ${labelEnd}");

  // then
  alines.add("label ${labelThen}");
  alines.add("  set_reg_a 0");

  alines.add("label ${labelEnd}");

  return alines;
}

List genExpr(fnArgNames, lvarNames, exp) {
  var alines = [];

  final op = exp[0];
  final args = getRest(exp);

  final argL = args[0];
  final argR = args[1];

  alines += _genExpr_push(fnArgNames, lvarNames, argL);
  alines += _genExpr_push(fnArgNames, lvarNames, argR);

  if (op == "+") {
    alines += _genExpr_add();
  } else if (op == "*") {
    alines += _genExpr_mult();
  } else if (op == "eq") {
    alines += _genExpr_eq();
  } else if (op == "neq") {
    alines += _genExpr_neq();
  } else {
    throw notYetImpl([ op ]);
  }

  return alines;
}

List genVar(fnArgNames, lvarNames, stmtRest) {
  var alines = [];

  alines.add("  sub_sp 1");

  if (stmtRest.length == 2) {
    alines += genSet(fnArgNames, lvarNames, stmtRest);
  }

  return alines;
}

List _genCall_pushFnArg(fnArgNames, lvarNames, fnArg) {
  var alines = [];

  final pushArg;

  if (fnArg is int) {
    pushArg = fnArg;
  } else if (fnArg is String) {
    if (fnArgNames.contains(fnArg)) {
      pushArg = toFnArgRef(fnArgNames, fnArg);
    } else if (lvarNames.contains(fnArg)) {
      pushArg = toLvarRef(lvarNames, fnArg);
    } else {
      throw notYetImpl([ fnArg ]);
    }
  } else {
    throw notYetImpl([ fnArg ]);
  }

  alines.add("  push ${pushArg}");

  return alines;
}

List genCall(fnArgNames, lvarNames, stmtRest) {
  var alines = [];

  final fnName = stmtRest[0];
  final fnArgs = getRest(stmtRest);

  fnArgs.reversed.forEach((fnArg){
      alines += _genCall_pushFnArg(
        fnArgNames, lvarNames, fnArg
      );
  });

  alines += genVmComment("call  ${fnName}");
  alines.add("  call ${fnName}");
  alines.add("  add_sp ${fnArgs.length}");

  return alines;
}

List genCallSet(fnArgNames, lvarNames, stmtRest) {
  var alines = [];

  final lvarName = stmtRest[0];
  final fnTemp = stmtRest[1];

  final fnName = fnTemp[0];
  final fnArgs = getRest(fnTemp);

  fnArgs.reversed.forEach((fnArg){
      alines += _genCall_pushFnArg(
        fnArgNames, lvarNames, fnArg
      );
  });

  alines += genVmComment("call_set  ${fnName}");
  alines.add("  call ${fnName}");
  alines.add("  add_sp ${fnArgs.length}");

  final lvarRef = toLvarRef(lvarNames, lvarName);
  alines.add("  cp reg_a ${lvarRef}");

  return alines;
}

String? _matchVramRef_index(val) {
  final re = new RegExp(r'^vram\[(\d+)\]');

  final m = re.firstMatch(val);
  if (m == null) {
    return null;
  }

  return m.group(1);
}

String? _matchVramRef_ident(val) {
  final re = new RegExp(r'^vram\[([a-z0-9_]+)\]');

  final m = re.firstMatch(val);
  if (m == null) {
    return null;
  }

  return m.group(1);
}

List _genSet_set(lvarNames, srcVal, dest) {
  var alines = [];

  if (_matchVramRef_index(dest) != null) {
    final vramAddr = _matchVramRef_index(dest);
    alines.add("  set_vram ${vramAddr} ${srcVal}");
  } else if (_matchVramRef_ident(dest) != null) {
    final varName = _matchVramRef_ident(dest);
    if (lvarNames.contains(varName)) {
      final ref = toLvarRef(lvarNames, varName);
      alines.add("  set_vram ${ref} ${srcVal}");
    } else {
      throw notYetImpl([ varName ]);
    }
  } else {
    final lvarRef = toLvarRef(lvarNames, dest);
    alines.add("  cp ${srcVal} ${lvarRef}");
  }

  return alines;
}

List genSet(fnArgNames, lvarNames, rest) {
  var alines = [];
  final dest = rest[0];
  final exp = rest[1];

  var srcVal;
  if (exp is int) {
    srcVal = exp;
  } else if (exp is String) {
    if (fnArgNames.contains(exp)) {
      srcVal = toFnArgRef(fnArgNames, exp);
    } else if (lvarNames.contains(exp)) {
      srcVal = toLvarRef(lvarNames, exp);
    } else if ( _matchVramRef_index(exp) != null ) {
      final vramAddr = _matchVramRef_index(exp);
      alines.add("  get_vram ${vramAddr} reg_a");
      srcVal = "reg_a";
    } else if ( _matchVramRef_ident(exp) != null ) {
      final varName = _matchVramRef_ident(exp);
      
      if (lvarNames.contains(varName)) {
        final ref = toLvarRef(lvarNames, varName);
        alines.add("  get_vram ${ref} reg_a");
      } else {
        throw notYetImpl([ varName ]);
      }
      srcVal = "reg_a";

    } else {
      throw notYetImpl([ exp ]);
    }
  } else if (exp is List) {
    alines += genExpr(fnArgNames, lvarNames, exp);
    srcVal = "reg_a";
  } else {
    throw notYetImpl([ exp ]);
  }

  alines += _genSet_set(lvarNames, srcVal, dest);

  return alines;
}

List genReturn(lvarNames, stmtRest) {
  var alines = [];

  final retval = stmtRest[0];

  if (retval is int) {
    alines.add("  cp ${retval} reg_a");
  } else if (retval is String) {

    if (_matchVramRef_ident(retval) != null) {
      final varName = _matchVramRef_ident(retval);

      if (lvarNames.contains(varName)) {
        final ref = toLvarRef(lvarNames, varName);
        alines.add("  get_vram ${ref} reg_a");
      } else {
        throw notYetImpl([ retval ]);
      }

    } else if (lvarNames.contains(retval)) {
      final lvarRef = toLvarRef(lvarNames, retval);
      alines.add("  cp ${lvarRef} reg_a");
    } else {
      throw notYetImpl([ retval ]);
    }

  } else {
    throw notYetImpl([ retval ]);
  }

  return alines;
}

List genWhile(fnArgNames, lvarNames, rest) {
  var alines = [];
  final condExp = rest[0];
  final body = rest[1];

  globalLabelId++;
  final labelId = globalLabelId;

  final labelBegin = "while_${labelId}";
  final labelEnd = "end_while_${labelId}";
  final labelTrue = "true_${labelId}";

  alines.add("");

  // ループの先頭
  alines.add("label ${labelBegin}");

  // 条件の評価
  alines += genExpr(fnArgNames, lvarNames, condExp);

  // 比較対象の値（真）をセット
  alines.add("  set_reg_b 1");
  alines.add("  compare");

  // true の場合ループの本体を実行
  alines.add("  jump_eq ${labelTrue}");

  // false の場合ループを抜ける
  alines.add("  jump ${labelEnd}");

  alines.add("label ${labelTrue}");

  // ループの本体
  alines += genStmts(fnArgNames, lvarNames, body);

  // ループの先頭に戻る
  alines.add("  jump ${labelBegin}");

  alines.add("label ${labelEnd}");
  alines.add("");

  return alines;
}

List genCase(fnArgNames, lvarNames, whenBlocks) {
  var alines = [];

  globalLabelId++;
  final labelId = globalLabelId;

  final labelEnd = "end_case_${labelId}";
  final labelWhenHead = "when_${labelId}";
  final labelEndWhenHead = "end_when_${labelId}";

  var whenIdx = -1;

  whenBlocks.forEach((whenBlock){
      whenIdx++;

      final cond = whenBlock[0];
      final rest = getRest(whenBlock);

      final condHead = cond[0];
      final condRest = getRest(cond);

      alines.add("  # 条件 ${labelId}_${whenIdx}: ${inspect(cond)}");

      if (condHead == "eq") {
        alines += genExpr(fnArgNames, lvarNames, cond);

        alines.add("  set_reg_b 1");

        alines.add("  compare");
        alines.add("  jump_eq ${labelWhenHead}_${whenIdx}");
        alines.add("  jump ${labelEndWhenHead}_${whenIdx}");

        alines.add("label ${labelWhenHead}_${whenIdx}");

        alines += genStmts(fnArgNames, lvarNames, rest);

        alines.add("  jump ${labelEnd}");

        alines.add("label ${labelEndWhenHead}_${whenIdx}");

      } else {
        throw notYetImpl([ condHead ]);
      }
  });

  alines.add("label end_case_${labelId}");

  return alines;
}

List genVmComment(comment) {
  return [
    "  _cmt " + comment.replaceAll(" ", "~")
  ];
}

List genStmt(fnArgNames, lvarNames, stmt) {
  var alines = [];

  final stmtHead = stmt[0];
  final stmtRest = getRest(stmt);

  if (stmtHead == "call") {
    alines += genCall(fnArgNames, lvarNames, stmtRest);

  } else if (stmtHead == "call_set") {
    alines += genCallSet(fnArgNames, lvarNames, stmtRest);

  } else if (stmtHead == "set") {
    alines += genSet(fnArgNames, lvarNames, stmtRest);

  } else if (stmtHead == "return") {
    alines += genReturn(lvarNames, stmtRest);

  } else if (stmtHead == "while") {
    alines += genWhile(fnArgNames, lvarNames, stmtRest);

  } else if (stmtHead == "case") {
    alines += genCase(fnArgNames, lvarNames, stmtRest);

  } else if (stmtHead == "_cmt") {
    alines += genVmComment(stmtRest[0]);

  } else {
    throw notYetImpl([ stmtHead ]);
  }

  return alines;
}

List genStmts(fnArgNames, lvarNames, stmts) {
  var alines = [];

  var stmtHead;
  var stmtRest;

  stmts.forEach((stmt){
      alines += genStmt(fnArgNames, lvarNames, stmt);
  });

  return alines;
}

List genFuncDef(rest) {
  var alines = [];

  final fnName = rest[0];
  final fnArgNames = rest[1];
  final body = rest[2];

  alines.add("");
  alines.add("label " + fnName);
  alines.add("  push bp");
  alines.add("  cp sp bp");

  alines.add("");
  alines.add("  # 関数の処理本体");

  final lvarNames = [];

  body.forEach((stmt){
      final stmtRest = getRest(stmt);
      if (stmt[0] == "var") {
        lvarNames.add(stmtRest[0]);
        alines += genVar(fnArgNames, lvarNames, stmtRest);
      } else {
        alines += genStmt(fnArgNames, lvarNames, stmt);
      }
  });

  alines.add("");
  alines.add("  cp bp sp");
  alines.add("  pop bp");
  alines.add("  ret");

  return alines;
}

List genTopStmts(rest) {
  var alines = [];

  rest.forEach((stmt){
      final stmtHead = stmt[0];
      final stmtRest = getRest(stmt);

      if (stmtHead == "func") {
        alines += genFuncDef(stmtRest);
      } else {
        throw notYetImpl([stmtHead]);
      }
  });

  return alines;
}

List codegen(tree) {
  var alines = [];

  alines.add("  call main");
  alines.add("  exit");

  final head = tree[0];
  final rest = getRest(tree);

  alines += genTopStmts(rest);

  return alines;
}

main(){
  final src = readAll();
  final tree = parseJson(src);

  var alines;
  try {
    alines = codegen(tree);
  } catch(e, s) {
    puts_e(e);
    puts_e(s);
    throw e;
  }

  alines.forEach((aline){
      print(aline);
  });
}
