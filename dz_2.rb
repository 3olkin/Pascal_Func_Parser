# frozen_string_literal: true

$var_lib = []
$cur_part
$Error

def make_tokens(str)
  require 'strscan'
  operators = ['(', ')', '=', ':=', ';', ':', ',', 'fn', 'vr', 'ct', 'bg', 'nd']
  result = []
  types = %w[integer real boolean char]
  dictionary = %w[function begin end var const]
  scanner = StringScanner.new str
  until scanner.empty?
    if scanner.scan(/\s+/)
    # ignore whitespace
    elsif match = scanner.scan(/function\s/)
      result << ['fn', match]
    elsif match = scanner.scan(/var\s/)
      result << ['vr', match]
    elsif match = scanner.scan(/const\s/)
      result << ['ct', match]
    elsif match = scanner.scan(/begin\s/)
      result << ['bg', match]
    elsif match = scanner.scan(/end(?=\W)/)
      result << ['nd', match]
    elsif match = scanner.scan(/[[:alpha:]](?:[[:alnum:]]|_)*(?=\W)/)
      result << if types.include?(match)
                  ['Tp', match]
                elsif dictionary.include?(match)
                  $Error = "Error! Reserved name: #{match}"
                  raise
                else
                  ['Id', match]
                end
    elsif match = scanner.scan(/(?:\-|\+)?[[:digit:]]+(?=\W)/)
      result << ['Nm', match]
    # operators
    elsif match = scanner.scan(/:=/)
      result << [':=', match]
    elsif match = scanner.scan(/=/)
      result << ['=', match]
    elsif match = scanner.scan(/,/)
      result << [',', match]
    elsif match = scanner.scan(/:/)
      result << [':', match]
    elsif match = scanner.scan(/\(/)
      result << ['(', match]
    elsif match = scanner.scan(/\)/)
      result << [')', match]
    elsif match = scanner.scan(/;/)
      result << [';', match]
    # error
    else
      # raise "can't recognize  <#{scanner.peek(5)}>"
      $Error = "Tokens ERROR :: unknown object: { #{scanner.peek(3)} }"
      raise
    end
  end
  # float length works correctly
  # добавление пустого операнда в нужные места
  i = 0
  situations = [[')', ':'], [';', 'ct'], [';', 'vr'], [';', 'fn'], [';', 'bg'], ['nd', ';']]
  while i < (result.length - 1)
    if situations.include?([result[i][0], result[i + 1][0]])
      result.insert(i + 1, ['@@', ''])
    end
    i += 1
  end
  # if operators.include?(result[i][0]) && operators.include?(result[i + 1][0])
  #   result.insert(i + 1, ['@@', ''])
  # end
  # i += 1
  if result.empty?
    $Error = 'File is empty!'
    raise
  end
  result.insert(0, ['@@', ''])
  result << ['##', '##'] # специальный символ конца разбора токенов
  result
end

def micro_parser(tokens, table, table_header, table_exit)
  stack = []
  row = 0
  while $it < tokens.length
    col = table_header.index(tokens[$it][0])
    col = (table[0].length - 1) if col.nil?
    case table[row][col]
    when 1
      stack.push($it - 1)
    when 3
      tmp = []
      i0 = stack.pop
      (i0..$it).each do |k|
        tmp.push(tokens[k][0]) if tokens[k][0] != '@@'
      end
      $command.push(tmp.join(' '))
      vocabulary(i0, tokens)
    when 99
      # проверка на переход на следующий блок
      if table_exit.include?(tokens[$it][0])
        if tokens[$it - 2][0] == ';'
          return true
        else
          $Error = "Parser ERROR :: Symb {;} missed before #{tokens[$it][0]} at #{$it}"
          raise
        end
      else
        $Error = "Parser ERROR :: before token #{tokens[$it][0]} at #{$it}"
        raise
      end
    end
    row = col + 1
    $it += 2
  end
end

def macro_parser(tokens)
  # block of function declaration
  table_funcname_header = ['fn', ',', ':', '(', ')', ';']
  table_funcname_exit = %w[fn ct vr bg]
  table_funcname = [[1, 99, 99, 99, 99, 99, 99], [99, 99, 2, 2, 99, 99, 99], [99, 2, 2, 99, 99, 99, 99], [99, 99, 99, 99, 3, 3, 99], [99, 1, 1, 99, 99, 99, 99], [99, 99, 2, 99, 99, 99, 99], [99, 1, 99, 99, 99, 99, 99]]
  # block of definitions // может отсутствовать
  table_def_header = [',', ':', '=', 'vr', 'ct', ';']
  table_def_exit = %w[bg fn]
  table_def = [[99, 99, 99, 1, 1, 99, 99], [2, 2, 99, 99, 99, 99, 99], [99, 99, 99, 99, 99, 3, 99], [99, 99, 99, 99, 99, 3, 99], [2, 2, 99, 99, 99, 99, 99], [99, 99, 2, 99, 99, 99, 99], [99, 1, 1, 1, 99, 99, 99]]
  # block of operators
  table_block_header = ['bg', 'nd', ':=', ';']
  table_block_exit = ['bg', 'fn', '##']
  table_block = [[1, 99, 99, 99, 99], [99, 99, 1, 99, 99], [99, 99, 99, 3, 99], [99, 3, 99, 3, 99], [99, 99, 1, 99, 99]]
  ###
  $cur_part = 0
  $command.push('~~~~~ Function declaration ~~~~~~')
  micro_parser(tokens, table_funcname, table_funcname_header, table_funcname_exit)
  if (tokens[$it][0] == 'vr') || (tokens[$it][0] == 'ct')
    $cur_part = 1
    $command.push('~~~~~ Definitions Const and Var ~~~~~~')
    micro_parser(tokens, table_def, table_def_header, table_def_exit)
  end
  while tokens[$it][0] == 'fn'
    $cur_part = 0
    macro_parser(tokens)
  end
  $cur_part = 2
  $command.push('~~~~~ Block of operators ~~~~~')
  micro_parser(tokens, table_block, table_block_header, table_block_exit)
end

def vocabulary(index, tokens)
  case tokens[$it - 2][0]
  when ':'
    if $cur_part == 1
      tmp = index
      tmp += 2 if %w[vr ct].include?(tokens[index + 1][0])
      while tmp < ($it - 2)
        if tokens[tmp][0] == 'Id'
          $var_lib.push(['Var', tokens[tmp][1], tokens[$it - 1][1]])
          tmp += 2
        else
          $Error = "Error! Incorrect varname: #{tokens[tmp][1]}"
          raise
        end
      end
    end
    if $cur_part == 0
      if tokens[index + 1][0] == 'fn'
        if tokens[index + 2][0] == 'Id'
          $var_lib.push(['Func', tokens[index + 2][1], tokens[$it - 1][1]])
        else
          $Error = "Error! Incorrect funcname: #{tokens[index + 2][1]}"
          raise
        end
      else
        tmp = index
        while tmp < ($it - 2)
          if tokens[tmp][0] == 'Id'
            $var_lib.push(['Params', tokens[tmp][1], tokens[$it - 1][1]])
            tmp += 2
          else
            $Error = "Error! Incorrect param: #{tokens[tmp][1]}"
            raise
          end
        end
      end
    end
  when '='
    if tokens[$it - 3][0] == 'Id'
      $var_lib.push(['Const', tokens[$it - 3][1], tokens[$it - 1][1]])
    else
      $Error = "Error! Incorrect constname: #{tokens[$it - 3][1]}"
      raise
    end
  end
end

current_path = File.dirname(__FILE__)
file_path = current_path + '/prog.pas'

if File.exist?(file_path)
  file = File.new(file_path, 'r')
  lines = file.readlines
  file.close
  inputed = lines.join(' ').delete("\n").downcase.squeeze(' ')
  p inputed
  begin
    tokens = make_tokens(inputed)
    tokens_show = (tokens.map { |el| el[0] }).join(' ')
    # next until tokens_show.sub!('_', '').nil?
    p tokens_show
    $it = 1
    $command = []
    macro_parser(tokens)
    puts $command
    puts '>>> Vocabulary <<<'
    $var_lib.each { |el| p el }
  rescue StandardError
    puts $Error
  end
else
  puts 'Error! File not found'
end
