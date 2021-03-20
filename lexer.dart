import 'lib/types.dart';
import 'lib/utils.dart';

String? _match(pattern, str) {
  final m = new RegExp(pattern).firstMatch(str);
  if (m == null) {
    return null;
  }

  return m.group(1);
}

String? _matchSpace(str)   => _match(r'^([ \n]+)', str);
String? _matchComment(str) => _match(r'^(//.*)', str);
String? _matchString(str)  => _match(r'^"(.*)"', str);
String? _matchKeyword(str) => _match(r'^(func|set|var|call_set|call|return|case|while|_cmt)[^a-z_]', str);
String? _matchNumber(str)  => _match(r'^(-?[0-9]+)', str);
String? _matchSymbol(str)  => _match(r'^(==|!=|[(){}=;+*,])', str);
String? _matchIdent(str)   => _match(r'^([a-z_][a-z0-9_\[\]]*)', str);

void main() {
  final String src = readAll();

  int pos = 0;
  List<Token> tokens = [];

  while (pos < src.length) {
    final rest = src.substring(pos);

    if (_matchSpace(rest) != null) {
      final str = _matchSpace(rest)!;
      pos += str.length;
    } else if (_matchComment(rest) != null) {
      final str = _matchComment(rest)!;
      pos += str.length;
    } else if (_matchString(rest) != null) {
      final str = _matchString(rest)!;
      tokens.add(new Token("string", str));
      pos += str.length + 2;
    } else if (_matchKeyword(rest) != null) {
      final str = _matchKeyword(rest)!;
      tokens.add(new Token("keyword", str));
      pos += str.length;
    } else if (_matchNumber(rest) != null) {
      final str = _matchNumber(rest)!;
      tokens.add(new Token("int", str));
      pos += str.length;
    } else if (_matchSymbol(rest) != null) {
      final str = _matchSymbol(rest)!;
      tokens.add(new Token("symbol", str));
      pos += str.length;
    } else if (_matchIdent(rest) != null) {
      final str = _matchIdent(rest)!;
      tokens.add(new Token("ident", str));
      pos += str.length;
    } else {
      throw notYetImpl([ rest ]);
    }
  }

  for (var i=0; i<tokens.length; i++) {
    final t = tokens[i];
    print(t.type + "<" + t.value + ">");
  }
}
