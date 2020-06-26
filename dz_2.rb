# frozen_string_literal: true

$var_lib = []

def make_tokens(str)
  require 'strscan'
  operators = ['(', ')', '=', ':=', ';', ':', ',', 'fn', 'vr', 'ct', 'bg', 'nd']
  result = []
  types = %w[integer real boolean char]
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
    elsif match = scanner.scan(/[[:alpha:]](?:[[:alnum:]]|_)*(?=\W)/) # ??
      result << if types.include?(match)
                  ['Tp', match]
                else
                  ['Id', match]
                end
    elsif match = scanner.scan(/(?:\-|\+)?[[:digit:]]+(?=\W)/) # ??
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
      p "can't recognize  { #{scanner.peek(3)} }" # TODO: select number of shown symbs
      break
    end
  end
  # float length works correctly
  i = 0
  while i < (result.length - 1)
    if operators.include?(result[i][0]) && operators.include?(result[i + 1][0])
      result.insert(i + 1, ['@@', ''])
    end
    i += 1
  end
  result.insert(0, ['@@', ''])
  result << ['##', '##'] # специальный символ конца разбора токенов
  result
end

def triple_parser(tokens)
  case tokens[$it - 2][0]
  when ':='
    $command.push('op1 := op2    set value')
  end
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
      (stack.pop..$it).each do |k|
        tmp.push(tokens[k][0]) if tokens[k][0] != '@@'
      end
      $command.push(tmp.join(' '))
    when 4 # !!
      tmp = []
      (stack.pop..$it).each do |k|
        tmp.push(tokens[k][0]) if tokens[k][0] != '@@'
      end
      $command.push(tmp.join(' '))
    when 99
      # проверка на переход на следующий блок
      if table_exit.include?(tokens[$it][0])
        if tokens[$it - 2][0] == ';'
          puts "stack!#{stack.length}" unless stack.empty?
          return true
        else
          puts "Error! Symb {;} missed before #{tokens[$it][0]} "
          return false
        end
      else
        # error
        puts 'Error!!!'
        puts tokens[$it][0]
        puts $it
        return false
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
  table_funcname = [[1, 99, 99, 99, 99, 99, 99], [99, 99, 2, 2, 99, 99, 99], [99, 2, 2, 99, 99, 99, 99], [99, 99, 99, 99, 4, 3, 99], [99, 1, 1, 99, 99, 99, 99], [99, 99, 2, 99, 99, 99, 99], [99, 1, 99, 99, 99, 99, 99]]
  # block of definitions // может отсутствовать
  table_def_header = [',', ':', '=', 'vr', 'ct', ';']
  table_def_exit = %w[bg fn]
  table_def = [[99, 99, 99, 1, 1, 99, 99], [2, 2, 99, 99, 99, 99, 99], [99, 99, 99, 99, 99, 3, 99], [99, 99, 99, 99, 99, 3, 99], [2, 2, 99, 99, 99, 99, 99], [99, 99, 2, 99, 99, 99, 99], [99, 1, 1, 1, 99, 99, 99]]
  # block of operators
  table_block_header = ['bg', 'nd', ':=', ';']
  table_block_exit = ['bg', 'fn', '##']
  table_block = [[1, 99, 99, 99, 99], [99, 99, 1, 99, 99], [99, 99, 99, 3, 99], [99, 3, 99, 3, 99], [99, 99, 1, 99, 99]]
  ###
  $command.push('~~~~~ Function ~~~~~~')
  micro_parser(tokens, table_funcname, table_funcname_header, table_funcname_exit)
  if (tokens[$it][0] == 'vr') || (tokens[$it][0] == 'ct')
    $command.push('~~~~~ Definitions Const and Var ~~~~~~')
    micro_parser(tokens, table_def, table_def_header, table_def_exit)
  end
  macro_parser(tokens) while tokens[$it][0] == 'fn'
  $command.push('~~~~~ Block of operators ~~~~~')
  micro_parser(tokens, table_block, table_block_header, table_block_exit)
end

current_path = File.dirname(__FILE__)
file_path = current_path + '/prog.pas'

if File.exist?(file_path)
  file = File.new(file_path, 'r')
  lines = file.readlines
  file.close
  inputed = lines.join(' ').delete("\n").downcase.squeeze(' ')
  p inputed
  tokens = make_tokens(inputed)
  # отладка, сформированная строка токенов
  tokens_show = (tokens.map { |el| el[0] }).join(' ')
  next until tokens_show.sub!('_', '').nil?
  p tokens_show
  # конец
  $it = 1
  $command = []
  macro_parser(tokens)
  puts $command
else
  puts 'Ошибка! Файл не найден.'
  puts 'Проверьте имя файла и его расположение.'
end
