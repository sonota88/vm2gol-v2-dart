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

List codegenWhile(fnArgNames, lvarNames, rest) {
  var alines = [];
  final condExp = rest[0];
  final body = rest[1];

  globalLabelId++;
  final labelId = globalLabelId;

  alines.add("");

  // ループの先頭
  alines.add("label while_${labelId}");

  // 条件の評価
  alines += codegenExp(fnArgNames, lvarNames, condExp);

  // 比較対象の値（真）をセット
  alines.add("  set_reg_b 1");
  alines.add("  compare");

  // true の場合ループの本体を実行
  alines.add("  jump_eq true_${labelId}");

  // false の場合ループを抜ける
  alines.add("  jump end_while_${labelId}");

  alines.add("label true_${labelId}");

  // ループの本体
  alines += codegenStmts(fnArgNames, lvarNames, body);

  // ループの先頭に戻る
  alines.add("  jump while_${labelId}");

  alines.add("label end_while_${labelId}");
  alines.add("");

  return alines;
}

List codegenCase(fnArgNames, lvarNames, whenBlocks) {
  var alines = [];

  globalLabelId++;
  final labelId = globalLabelId;

  var whenIdx = -1;
  final thenBodies = [];

  whenBlocks.forEach((whenBlock){
      whenIdx++;

      final cond = whenBlock[0];
      final rest = getRest(whenBlock);

      final condHead = cond[0];
      final condRest = getRest(cond);

      alines.add("  # 条件 ${labelId}_${whenIdx}: ${inspect(cond)}");

      if (condHead == "eq") {
        alines += codegenExp(fnArgNames, lvarNames, cond);

        alines.add("  set_reg_b 1");

        alines.add("  compare");
        alines.add("  jump_eq when_${labelId}_${whenIdx}");

        var thenAlines = [];
        thenAlines.add("label when_${labelId}_${whenIdx}");
        thenAlines += codegenStmts(fnArgNames, lvarNames, rest);
        thenAlines.add("  jump end_case_${labelId}");
        thenBodies.add(thenAlines);
      } else {
        throw notYetImpl([ condHead ]);
      }
  });

  alines.add("  jump end_case_${labelId}");

  thenBodies.forEach((thenAlines){
      alines += thenAlines;
  });

  alines.add("label end_case_${labelId}");

  return alines;
}

List _codegenExp_push(fnArgNames, lvarNames, val) {
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
    alines += codegenExp(fnArgNames, lvarNames, val);
    pushArg = "reg_a";
  } else {
    throw notYetImpl([ val ]);
  }

  alines.add("  push ${pushArg}");

  return alines;
}

List _codegenExp_add() {
  var alines = [];

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");
  alines.add("  add_ab");

  return alines;
}

List _codegenExp_mult() {
  var alines = [];

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");
  alines.add("  mult_ab");

  return alines;
}

List _codegenExp_eq() {
  final alines = [];

  globalLabelId++;
  final labelId = globalLabelId;

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");

  alines.add("  compare");
  alines.add("  jump_eq then_${labelId}");

  // else
  alines.add("  set_reg_a 0");
  alines.add("  jump end_eq_${labelId}");

  // then
  alines.add("label then_${labelId}");
  alines.add("  set_reg_a 1");

  alines.add("label end_eq_${labelId}");

  return alines;
}

List _codegenExp_neq() {
  final alines = [];

  globalLabelId++;
  final labelId = globalLabelId;

  alines.add("  pop reg_b");
  alines.add("  pop reg_a");

  alines.add("  compare");
  alines.add("  jump_eq then_${labelId}");

  // else
  alines.add("  set_reg_a 1");
  alines.add("  jump end_neq_${labelId}");

  // then
  alines.add("label then_${labelId}");
  alines.add("  set_reg_a 0");

  alines.add("label end_neq_${labelId}");

  return alines;
}

List codegenExp(fnArgNames, lvarNames, exp) {
  var alines = [];

  final op = exp[0];
  final args = getRest(exp);

  final argL = args[0];
  final argR = args[1];

  alines += _codegenExp_push(fnArgNames, lvarNames, argL);
  alines += _codegenExp_push(fnArgNames, lvarNames, argR);

  if (op == "+") {
    alines += _codegenExp_add();
  } else if (op == "*") {
    alines += _codegenExp_mult();
  } else if (op == "eq") {
    alines += _codegenExp_eq();
  } else if (op == "neq") {
    alines += _codegenExp_neq();
  } else {
    throw notYetImpl([ op ]);
  }

  return alines;
}

List _codegenCall_pushFnArg(fnArgNames, lvarNames, fnArg) {
  var alines = [];

  if (fnArg is int) {
    alines.add("  push ${fnArg}");
  } else if (fnArg is String) {
    if (fnArgNames.contains(fnArg)) {
      final ref = toFnArgRef(fnArgNames, fnArg);
      alines.add("  push ${ref}");
    } else if (lvarNames.contains(fnArg)) {
      final ref = toLvarRef(lvarNames, fnArg);
      alines.add("  push ${ref}");
    } else {
      throw notYetImpl([ fnArg ]);
    }
  } else {
    throw notYetImpl([ fnArg ]);
  }

  return alines;
}

List codegenCall(fnArgNames, lvarNames, stmtRest) {
  var alines = [];

  final fnName = stmtRest[0];
  final fnArgs = getRest(stmtRest);

  fnArgs.reversed.forEach((fnArg){
      alines += _codegenCall_pushFnArg(
        fnArgNames, lvarNames, fnArg
      );
  });

  alines += codegenVmComment("call  ${fnName}");
  alines.add("  call ${fnName}");
  alines.add("  add_sp ${fnArgs.length}");

  return alines;
}

List codegenCallSet(fnArgNames, lvarNames, stmtRest) {
  var alines = [];

  final lvarName = stmtRest[0];
  final fnTemp = stmtRest[1];

  final fnName = fnTemp[0];
  final fnArgs = getRest(fnTemp);

  fnArgs.reversed.forEach((fnArg){
      alines += _codegenCall_pushFnArg(
        fnArgNames, lvarNames, fnArg
      );
  });

  alines += codegenVmComment("call_set  ${fnName}");
  alines.add("  call ${fnName}");
  alines.add("  add_sp ${fnArgs.length}");

  final lvarRef = toLvarRef(lvarNames, lvarName);
  alines.add("  cp reg_a ${lvarRef}");

  return alines;
}

String _matchVramRef_index(val) {
  final re = new RegExp(r'^vram\[(\d+)\]');

  final m = re.firstMatch(val);
  if (m == null) {
    return null;
  }

  return m.group(1);
}

String _matchVramRef_ident(val) {
  final re = new RegExp(r'^vram\[([a-z0-9_]+)\]');

  final m = re.firstMatch(val);
  if (m == null) {
    return null;
  }

  return m.group(1);
}

List _codegenSet_set(lvarNames, srcVal, dest) {
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

List codegenSet(fnArgNames, lvarNames, rest) {
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
    alines += codegenExp(fnArgNames, lvarNames, exp);
    srcVal = "reg_a";
  } else {
    throw notYetImpl([ exp ]);
  }

  alines += _codegenSet_set(lvarNames, srcVal, dest);

  return alines;
}

List codegenReturn(lvarNames, stmtRest) {
  var alines = [];

  final retval = stmtRest[0];

  if (retval is int) {
    alines.add("  set_reg_a ${retval}");
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

List codegenVmComment(comment) {
  return [
    "  _cmt " + comment.replaceAll(" ", "~")
  ];
}

List codegenStmts(fnArgNames, lvarNames, stmts) {
  var alines = [];

  var stmtHead;
  var stmtRest;

  stmts.forEach((stmt){
      stmtHead = stmt[0];
      stmtRest = getRest(stmt);

      if (stmtHead == "call") {
        alines += codegenCall(fnArgNames, lvarNames, stmtRest);

      } else if (stmtHead == "call_set") {
        alines += codegenCallSet(fnArgNames, lvarNames, stmtRest);

      } else if (stmtHead == "var") {
        lvarNames.add(stmtRest[0]);
        alines.add("  sub_sp 1");
        if (stmtRest.length == 2) {
          alines += codegenSet(fnArgNames, lvarNames, stmtRest);
        }

      } else if (stmtHead == "set") {
        alines += codegenSet(fnArgNames, lvarNames, stmtRest);

      } else if (stmtHead == "return") {
        alines += codegenReturn(lvarNames, stmtRest);

      } else if (stmtHead == "case") {
        alines += codegenCase(fnArgNames, lvarNames, stmtRest);

      } else if (stmtHead == "while") {
        alines += codegenWhile(fnArgNames, lvarNames, stmtRest);

      } else if (stmtHead == "_cmt") {
        alines += codegenVmComment(stmtRest[0]);

      } else {
        throw notYetImpl([ stmtHead ]);
      }
  });

  return alines;
}

List codegenFuncDef(rest) {
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

  alines += codegenStmts(fnArgNames, lvarNames, body);

  alines.add("");
  alines.add("  cp bp sp");
  alines.add("  pop bp");
  alines.add("  ret");

  return alines;
}

List codegenTopStmts(rest) {
  var alines = [];

  rest.forEach((stmt){
      final stmtHead = stmt[0];
      final stmtRest = getRest(stmt);

      if (stmtHead == "func") {
        alines += codegenFuncDef(stmtRest);
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

  alines += codegenTopStmts(rest);

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
