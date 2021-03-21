import 'dart:convert';

import 'lib/types.dart';
import 'lib/utils.dart';

String toJson(tree) {
  var encoder = JsonEncoder.withIndent("  ");
  return encoder.convert(tree);
}

Exception parseError() {
  return new Exception("==== Failed to parse ====");
}

toTokens(src) {
  var lines = src.split("\n");

  var tokens = [];

  for (var i=0; i<lines.length; i++) {
    final line = lines[i];

    if (line == "") {
      break;
    }
    final re = new RegExp(r'^(.+)<(.+)>$');
    final RegExpMatch m = re.firstMatch(line)!;

    final String type = m.group(1)!;

    final String g2 = m.group(2)!;
    var value;
    if (type == "int") {
      value = int.parse(g2);
    } else {
      value = g2;
    }

    tokens.add(new Token(type, value));
  }

  return tokens;
}

// --------------------------------

var tokens;
var pos = 0;

Token peek([offset = 0]) {
  return tokens[pos + offset];
}

void dumpState() {
  puts_e(_restHead());
}

String _restHead() {
  var s = "";
  for (var i=pos; i<pos + 8; i++) {
    if (tokens.length <= i) {
      break;
    }
    var t = tokens[i];
    s += i.toString() + ": " + t.type + "<" + t.value + ">\n";
  }
  return s;
}

void assertValue(int pos, exp) {
  var t = tokens[pos];

  if (t.value != exp) {
    var msg = "Assertion failed: exp(" + exp + ") act(" + t.value + ")";
    throw Exception(msg);
  }
}

void consume(String str) {
  assertValue(pos, str);
  pos++;
}

bool isEnd() {
  return tokens.length <= pos;
}

// --------------------------------

_parseArg() {
  final t = peek();

  if (
    t.type == "ident" ||
    t.type == "int"
  ) {
    pos++;
    return t.value;
  } else {
    throw parseError();
  }
}

_parseArgs_first() {
  if (peek().value == ")") {
    return null;
  }

  return _parseArg();
}

_parseArgs_rest() {
  if (peek().value == ")") {
    return null;
  }

  consume(",");

  return _parseArg();
}

List parseArgs() {
  var args = [];

  final firstArg = _parseArgs_first();
  if (firstArg == null) {
    return args;
  } else {
    args.add(firstArg);
  }

  while (true) {
    final restArg = _parseArgs_rest();
    if (restArg == null) {
      break;
    } else {
      args.add(restArg);
    }
  }

  return args;
}

List parseFunc() {
  consume("func");

  final t = peek();
  pos++;
  final funcName = t.value;

  consume("(");
  final args = parseArgs();
  consume(")");

  consume("{");
  final stmts = parseStmts();
  consume("}");

  return ["func", funcName, args, stmts];
}

List _parseVar_declare() {
  final t = peek();
  pos++;
  final varName = t.value;

  consume(";");

  return ["var", varName];
}

List _parseVar_init() {
  final t = peek();
  pos++;
  final varName = t.value;

  consume("=");

  final expr = parseExpr();

  consume(";");

  return ["var", varName, expr];
}

List parseVar() {
  consume("var");

  final t = peek(1);

  if (t.value == ";") {
    return _parseVar_declare();
  } else if (t.value == "=") {
    return _parseVar_init();
  } else {
    throw parseError();
  }
}

_parseExprRight(exprL) {
  final t = peek();

  if (
    t.value == ";" ||
    t.value == ")"
  ) {
    return exprL;
  }

  if (t.value == "+") {
    consume("+");
    final exprR = parseExpr();
    return ["+", exprL, exprR];

  } else if (t.value == "*") {
    consume("*");
    final exprR = parseExpr();
    return ["*", exprL, exprR];

  } else if (t.value == "==") {
    consume("==");
    final exprR = parseExpr();
    return ["eq", exprL, exprR];

  } else if (t.value == "!=") {
    consume("!=");
    final exprR = parseExpr();
    return ["neq", exprL, exprR];

  } else {
    throw notYetImpl([ t ]);
  }
}

parseExpr() {
  final tLeft = peek();

  if (tLeft.value == "(") {
    consume("(");
    final exprL = parseExpr();
    consume(")");
    return _parseExprRight(exprL);
  }

  if (
    tLeft.type == "int" ||
    tLeft.type == "ident"
  ) {
    pos++;

    final exprL = tLeft.value;
    return _parseExprRight(exprL);
  } else {
    throw parseError();
  }
}

List parseSet() {
  consume("set");

  final t = peek();
  pos++;
  final varName = t.value;

  consume("=");

  final expr = parseExpr();

  consume(";");

  return ["set", varName, expr];
}

List parseFuncall() {
  final t = peek();
  pos++;
  final funcName = t.value;

  consume("(");
  final args = parseArgs();
  consume(")");

  return [funcName, ...args];
}

List parseCall() {
  consume("call");

  final funcall = parseFuncall();

  consume(";");

  return ["call", ... funcall];
}

List parseCallSet() {
  consume("call_set");

  final t = peek();
  pos++;
  final varName = t.value;

  consume("=");

  final expr = parseFuncall();

  consume(";");

  return ["call_set", varName, expr];
}

List parseReturn() {
  consume("return");

  Token t = peek();

  if (t.value == ";") {
    consume(";");
    return ["return"];
  } else {
    final expr = parseExpr();
    consume(";");
    return ["return", expr];
  }
}

List parseWhile() {
  consume("while");

  consume("(");
  final expr = parseExpr();
  consume(")");

  consume("{");
  final stmts = parseStmts();
  consume("}");

  return ["while", expr, stmts];
}

List? _parseWhenClause() {
  Token t = peek();
  if (t.value == "}") {
    return null;
  }

  consume("(");
  final expr = parseExpr();
  consume(")");

  consume("{");
  final stmts = parseStmts();
  consume("}");

  return [expr, ...stmts];
}

List parseCase() {
  consume("case");

  consume("{");

  var whenClauses = [];

  while (true) {
    final whenClause = _parseWhenClause();
    if (whenClause == null) {
      break;
    } else {
      whenClauses.add(whenClause);
    }
  }

  consume("}");

  return ["case", ...whenClauses];
}

List parseVmComment() {
  consume("_cmt");
  consume("(");

  final t = peek();
  pos++;
  final comment = t.value;

  consume(")");
  consume(";");

  return ["_cmt", comment];
}

List? parseStmt() {
  final t = peek();

  if (t.value == "}") {
    return null;
  }

  if      (t.value == "func"    ) { return parseFunc();      } 
  else if (t.value == "var"     ) { return parseVar();       }
  else if (t.value == "set"     ) { return parseSet();       }
  else if (t.value == "call"    ) { return parseCall();      }
  else if (t.value == "call_set") { return parseCallSet();   }
  else if (t.value == "return"  ) { return parseReturn();    }
  else if (t.value == "while"   ) { return parseWhile();     }
  else if (t.value == "case"    ) { return parseCase();      }
  else if (t.value == "_cmt"    ) { return parseVmComment(); }
  else {
    throw notYetImpl([ t ]);
  }
}

List parseStmts() {
  var stmts = [];

  while(true) {
    if (isEnd()) {
      break;
    }

    final stmt = parseStmt();
    if (stmt == null) {
      break;
    }

    stmts.add(stmt);
  }

  return stmts;
}

List parse(){
  final stmts = parseStmts();
  return ["stmts", ...stmts];
}

// --------------------------------

void main() {
  final src = readAll();

  tokens = toTokens(src);

  var tree;
  try {
    tree = parse();
  } catch(e, s) {
    puts_e(e);
    puts_e(s);
    dumpState();
    throw e;
  }

  print(toJson(tree));
}
