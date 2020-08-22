class Token {
  final type;
  final value;

  Token(this.type, this.value);

  String toString(){
    return this.type + "<" + this.value + ">";
  }
}
