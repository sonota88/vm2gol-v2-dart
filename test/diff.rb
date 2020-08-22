exp = ARGV[0]
act = ARGV[1]

out = `diff -u #{exp} #{act}`

C_MINUS = "\e[0;31m" # red
C_PLUS  = "\e[0;32m" # green
C_AT    = "\e[0;34m" # blue
C_RESET = "\e[m"

exit 0 if out.empty?

out.lines.each{ |line|
  case line
  when /^ /
    print line
  when /^-/
    print C_MINUS + line + C_RESET
  when /^\+/
    print C_PLUS  + line + C_RESET
  when /^@/
    print C_AT    + line + C_RESET
  else
    print line
  end
}

exit 1
