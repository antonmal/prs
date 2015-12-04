require 'colorize'

# Handles human player moves in the game.
class Player
  attr_accessor :move

  def make_move
    move_char = ''
    loop do
      puts
      puts prompt
      move_char = gets.chomp.downcase
      break if valid_move?(move_char)
    end
    @move = Move.new(move_char)
    puts 'You chose:       ' + "#{Move::OPTIONS[move_char].upcase}\n".light_cyan
  end

  private

  def prompt
    Move.prompt
  end

  def valid_move?(move)
    Move.chars.include? move
  end
end

# Handles computer moves in the game
# and 'personalities' that affect these moves
class Computer
  attr_accessor :move, :personality, :results

  PERSONALITIES = [
    { name: 'R2D2', probabilities: { 'p' => 0, 'r' => 80, 's' => 20 } },
    { name: 'Wall-E', probabilities: { 'p' => 50, 'r' => 0, 's' => 50 } },
    { name: 'Hulk', probabilities: { 'p' => 25, 'r' => 25, 's' => 50 } }
  ]
  USE_PERSONALITIES = true
  HUNDRED_PERCENT = 100.0

  def initialize(results)
    @results = results
    @personality = PERSONALITIES.sample
  end

  def name
    personality[:name]
  end

  def make_move
    if USE_PERSONALITIES
      @move = personality_biased_move
    elsif results.stats[:total] >= 3
      @move = smart_counter_move
    else
      @move = random_move
    end

    puts "#{name} chose:  " \
         "#{move.name.upcase}\n".yellow
  end

  def random_move
    random_move = Move.chars.sample
    Move.new(random_move)
  end

  def personality_biased_move
    choose_move_from(personality[:probabilities])
  end

  def smart_counter_move
    player_fav_move = choose_move_from(moves_with_probs)
    player_fav_move.opposite
  end

  def choose_move_from(move_hash)
    sum_of_probs = move_hash.values.inject(:+)
    rnd = rand(sum_of_probs + 1)
    move_hash.each do |move, prob|
      rnd -= prob
      return Move.new(move) if rnd <= 0
    end
  end

  def moves_with_probs
    Move.chars.each_with_object(Hash.new(0)) do |move, hash|
      hash[move] = historical_prob(move)
      hash[move] = unused_move_prob if hash[move] == 0
    end
  end

  def historical_prob(move)
    number_of_such_moves = results.log.count do |line|
      line[:player].value == move
    end
    total_moves_made = results.log.size.to_f
    (number_of_such_moves / total_moves_made * HUNDRED_PERCENT).ceil
  end

  def unused_move_prob
    # if user never made a specific move,
    # consider that the probability of him making that move next
    # is equal to 100% / number of move options / 2
    # in other words, half of average probability for each move
    (HUNDRED_PERCENT / Move.chars.size / 2).ceil
  end
end

# Stores results of game rounds and calculates statistics.
# Stats are then used for move choices and for game logic.
class Results
  attr_accessor :log, :stats

  def initialize
    @log = []
    @stats = []
  end

  def add_to_log(args)
    result = args.fetch(:result, :tied)
    player = args.fetch(:player, Move.new('p'))
    comp = args.fetch(:computer, Move.new('p'))
    log << { time: Time.now, result: result, player: player, computer: comp }
    update_stats
    update_perc
  end

  def update_stats
    self.stats = {
      total:  log.size,
      won:    count(:won),
      lost:   count(:lost),
      tied:   count(:tied)
    }
  end

  def count(result)
    log.count { |e| e[:result] == result }
  end

  def update_perc
    perc = {
      won_perc:    percentage(:won),
      lost_perc:   percentage(:lost),
      tied_perc:   percentage(:tied)
    }
    stats.merge!(perc)
  end

  def percentage(result)
    (stats[result].to_f / stats[:total] * 100).round(2)
  end

  def show_stats
    puts 'Stats:'
    puts stat_str(:won).light_green
    puts stat_str(:lost).light_red
    puts stat_str(:tied).light_blue
    puts
  end

  def stat_str(res)
    res_perc = "#{res}_perc".to_sym
    "#{res.capitalize}: #{stats[res]} game(s) [#{stats[res_perc]}%]"
  end

  def show_log
    log.each do |line|
      puts <<-STR.single_line_undent
        #{line[:time]} -
        #{line[:result].to_s.upcase}:
        #{line[:player].name.capitalize} vs.
        #{line[:computer].name.capitalize}
      STR
    end
    puts
  end

  def clear!
    @log = []
  end
end

# Manages the flow (logic) of the Paper-Rock-Scissors game.
# Displays game messages.
class PRS
  attr_accessor :player, :computer, :results

  WINS_LIMIT = 3
  VERSION = 'prs'
  # VERSION = 'prskl'

  def initialize
    @results = Results.new
    @player = Player.new
    @computer = Computer.new(@results)
  end

  def show_start_screen
    clear
    puts <<-STR.undent

      Welcome to Paper-Rock-Scissors game!

      You are playing against #{computer.name}

      Let's start...
    STR
    sleep 1
  end

  def play_round
    clear
    player.make_move
    computer.make_move
    show_move_result
    results.add_to_log(
      result: result,
      player: player.move,
      computer: computer.move
    )
    results.show_stats
  end

  def end_game
    results.show_log
    show_game_result
    clear_score
  end

  def next_round?
    puts 'Press any key to continue.'
    gets
  end

  def one_more_game?
    puts "\n=> Do you want to play again? (y/n)"
    gets.chomp.downcase != 'n'
  end

  def play
    show_start_screen
    loop do
      loop do
        play_round
        break if wins_limit_reached? || !next_round?
      end
      end_game
      break unless one_more_game?
    end
  end

  def clear_score
    @results.clear!
  end

  def wins_limit_reached?
    results.stats[:won] >= WINS_LIMIT || results.stats[:lost] >= WINS_LIMIT
  end

  def show_game_result
    if won?
      puts 'Congratulations! You WON!'
      puts "You were first to win #{WINS_LIMIT} games.\n"
    elsif lost?
      puts 'Oops, you LOST!'
      puts "#{computer.name} was first to win #{WINS_LIMIT} games\n"
    else
      puts "A tie? How could this happen?\n"
    end
  end

  def won?
    results.stats[:won] > results.stats[:lost]
  end

  def lost?
    results.stats[:lost] > results.stats[:won]
  end

  def result
    return :won if player.move > computer.move
    return :lost if player.move < computer.move
    :tied
  end

  def show_move_result
    case result
    when :won then say_won
    when :lost then say_lost
    else puts "It's a tie."
    end
    puts "\n"
  end

  def say_won
    puts "Congratulations! You WON!\n"
    puts Move.result_str(player.move, computer.move)
  end

  def say_lost
    puts "Sorry, you LOST...\n"
    puts Move.result_str(computer.move, player.move)
  end

  def clear
    system('clear') || system('cls')
  end
end

# Handles game moves: options, comparisons, winning combinations
class Move
  attr_accessor :value

  if PRS::VERSION == 'prskl'
    OPTIONS = {
      'p' => 'paper',
      'r' => 'rock',
      's' => 'scissors',
      'k' => 'spock',
      'l' => 'lizard'
    }

    WINNING_COMBINATIONS = {
      'sp' => 'Scissors cut Paper.',
      'pr' => 'Paper covers Rock.',
      'rl' => 'Rock crushes Lizard.',
      'lk' => 'Lizard poisons Spock.',
      'ks' => 'Spock smashes Scissors.',
      'sl' => 'Scissors decapitates Lizard.',
      'lp' => 'Lizard eats Paper.',
      'pk' => 'Paper disproves Spock.',
      'kr' => 'Spock vaporizes Rock.',
      'rs' => 'Rock crushes Scissors.'
    }
  else
    OPTIONS = {
      'p' => 'paper',
      'r' => 'rock',
      's' => 'scissors'
    }

    WINNING_COMBINATIONS = {
      'sp' => 'Scissors cut Paper.',
      'pr' => 'Paper covers Rock.',
      'rs' => 'Rock crushes Scissors.'
    }
  end

  def initialize(value)
    unless Move.chars.include? value
      fail ArgumentError, <<-MSG.undent
        Unrecognized move value: '#{value}'.
        Acceptable values: #{Move.chars.join(', ')}.
      MSG
    end

    @value = value
  end

  def to_s
    value
  end

  def name
    OPTIONS[value]
  end

  def >(other)
    combination = "#{value}#{other}"
    WINNING_COMBINATIONS.keys.include? combination
  end

  def <(other)
    combination = "#{value}#{other}"
    WINNING_COMBINATIONS.keys.include? combination.reverse
  end

  def ==(other)
    value.to_s == other.to_s
  end

  def opposite
    opposite_moves = Move.chars.select { |e| Move.new(e) > self }
    Move.new(opposite_moves.sample)
  end

  def self.prompt
    opts = OPTIONS.map { |k, v| v.sub(k, "(#{k.capitalize})") }
    opts[0..-2].join(', ') + ' or ' + opts[-1] + '?'
  end

  def self.result_str(move1, move2)
    WINNING_COMBINATIONS["#{move1}#{move2}"]
  end

  def self.chars
    OPTIONS.keys
  end
end

# Fix indentation for heredocs (milti-line strings)
class String
  def single_line_undent
    gsub(/^[ \t]+/, '').split("\n").join(' ')
  end

  def undent
    gsub(/^[ \t]+/, '')
  end
end

# Play the game

PRS.new.play
