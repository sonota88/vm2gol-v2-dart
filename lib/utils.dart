import 'dart:io';

String readAll() {
  var src = "";
  while (true) {
    final line = stdin.readLineSync();
    if (line == null) {
      break;
    }
    src += line + "\n";
  }

  return src;
}

void puts_e(arg) {
  stderr.write(arg);
  stderr.write("\n");
}

Exception notYetImpl(args) {
  var msg = "==== Not yet implemented ====";
  args.forEach((arg){
      msg += " (${arg})";
  });
  return new Exception(msg);
}

String inspect(arg) {
  if (arg is int) {
    return "${arg}";
  } else if (arg is String) {
    return '"' + arg + '"';
  } else if (arg is List) {
    var s = "[";
    var i = -1;
    arg.forEach((el){
        i++;
        if (i >= 1) {
          s += ", ";
        }
        s += inspect(el);
    });
    s += "]";
    return s;
  } else {
    throw notYetImpl([ arg ]);
  }
}
