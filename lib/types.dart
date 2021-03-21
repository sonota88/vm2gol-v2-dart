class Token {
  final type;
  final String value;

  Token(this.type, this.value);

  String toString(){
    return this.type + "<" + this.value + ">";
  }

  int getValueAsInt() {
    return int.parse(this.value);
  }
}
