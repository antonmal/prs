require 'pry'
require 'colorize'

class Player
  attr_accessor :move, :game

  def initialize(game)
    @game = game
  end

  def make_move
    begin
      puts
      puts Move.prompt
      move_char = gets.chomp.downcase
    end until Move::OPTIONS.keys.include? move_char
    @move = Move.new(move_char)
    puts  "You chose:       " +
          "#{Move::OPTIONS[move_char].upcase}\n".light_cyan
  end
end


class Computer < Player
  attr_accessor :personality

  PERSONALITIES = [
    { name: "R2D2", probabilities: { "p" => 0, "r" => 80, "s" => 20 } },
    { name: "Wall-E", probabilities: { "p" => 50, "r" => 0, "s" => 50 } }
  ]
  USE_PERSONALITIES = true

  def initialize(game)
    super
    @personality = PERSONALITIES.sample
  end

  def name
    personality[:name]
  end

  def make_move
    if USE_PERSONALITIES
      @move = personality_biased_move
    elsif game.results.log.size >= 3
      @move = smart_counter_move
    else
      @move = random_move
    end

    puts  "#{self.name} chose:  " +
          "#{move.name.upcase}\n".yellow
  end

  def personality_biased_move
    accumulated_prob = 0
    probs = personality[:probabilities].each_with_object({}) do |(k, v), hash|
              hash[k] = v + accumulated_prob
              accumulated_prob += v
            end
    rnd = rand(accumulated_prob)
    mv = probs.select {|k,v| v >= rnd }.keys.first
    Move.new(mv)
  end

  def random_move
    mv = Move::OPTIONS.keys.sample
    Move.new(mv)
  end

  def smart_counter_move
    accumulated_prob = 0
    unused_move_prob = 100.0 / Move::OPTIONS.keys.size / 2
    probs = Move::OPTIONS.keys.each_with_object(Hash.new(0)) do |m, h|
              this_move_prob = game.results.log.count{|e| e[:player] == m} / game.results.log.size.to_f * 100
              this_move_prob = unused_move_prob if this_move_prob == 0
              this_move_prob += accumulated_prob
              h[m] = this_move_prob.ceil
              accumulated_prob = this_move_prob.ceil
            end
    rnd = rand(accumulated_prob)
    mv = probs.select {|k,v| v >= rnd }.keys.first
    Move.new(mv)
  end


end

class Results
  attr_accessor :game, :log, :stats

  def initialize(game)
    @game = game
    @log = []
  end

  def add_to_log
    log << {
      time:     Time.now,
      result:   game.result,
      player:   game.player.move.to_s,
      computer: game.computer.move.to_s
    }
  end

  def stats
    {
      total:  log.size,
      won:    log.count { |e| e[:result] == :won },
      lost:   log.count { |e| e[:result] == :lost },
      tied:   log.count { |e| e[:result] == :tied }
    }
  end

  def perc
    {
      won:    (stats[:won].to_f / stats[:total] * 100).round(2),
      lost:   (stats[:lost].to_f / stats[:total] * 100).round(2),
      tied:   (stats[:tied].to_f / stats[:total] * 100).round(2)
    }
  end

  def show_stats
    puts "Stats:"
    puts "Won: #{stats[:won]} game(s) [#{perc[:won]}%]".light_green
    puts "Lost: #{stats[:lost]} game(s) [#{perc[:lost]}%]".light_red
    puts "Tied: #{stats[:tied]} game(s) [#{perc[:tied]}%]".light_blue
    puts
  end

  def show_log
    log.each do |line|
      puts "#{line[:time]} - " +
        "#{line[:result].to_s.upcase}: " + "#{Move::OPTIONS[line[:player]].capitalize} vs. " +
        "#{Move::OPTIONS[line[:computer]].capitalize}"
    end
    puts
  end

  def clear!
    @log = []
  end
end


class PRS
  attr_accessor :player, :computer, :results

  WINS_LIMIT = 3
  VERSION = 'prs'
  # VERSION = 'prskl'


  def initialize
    @player = Player.new(self)
    @computer = Computer.new(self)
    @results = Results.new(self)
  end

  def play
    clear
    puts "\nWelcome to Paper-Rock-Scissors game!\n\n"
    puts "You are playing against #{computer.name}.\n\n"
    puts "Let's start..."
    sleep 1

    loop do
      loop do
        clear
        player.make_move
        computer.make_move
        show_move_result

        results.add_to_log
        results.show_stats
        break if wins_limit_reached?

        puts "Press any key to continue."
        gets
      end

      results.show_log
      show_game_result

      puts "\n=> Do you want to play again? (y/n)".white.bold
      break unless gets.chomp.downcase == "y"
      clear_score
    end
  end

  def clear_score
    @results.clear!
  end

  def wins_limit_reached?
    results.stats[:won] >= WINS_LIMIT || results.stats[:lost] >= WINS_LIMIT
  end

  def show_game_result
    if results.stats[:won] > results.stats[:lost]
      puts "Congratulations! You WON!"
      puts "You were first to win #{WINS_LIMIT} games.\n"
    elsif results.stats[:lost] > results.stats[:won]
      puts "Oops, you LOST!"
      puts "#{computer.name} was first to win #{WINS_LIMIT} games\n"
    else
      puts "A tie? How could this happen?\n"
    end
  end

  def result
    return :won if player.move > computer.move
    return :lost if player.move < computer.move
    :tied
  end

  def show_move_result
    case result
    when :won
      puts "Congratulations! You WON!\n"
      puts Move.result_str(player.move, computer.move) + "\n\n"
    when :lost
      puts "Sorry, you LOST...\n"
      puts Move.result_str(computer.move, player.move) + "\n\n"
    else
      puts "It's a tie.\n\n"
    end
  end

  private

  def clear
    system('clear') || system('cls')
  end
end


class Move
  attr_accessor :value

  if PRS::VERSION == 'prskl'
    OPTIONS = {
      "p" => "paper",
      "r" => "rock",
      "s" => "scissors",
      "k" => "spock",
      "l" => "lizard"
    }

    WINNING_COMBINATIONS = {
      "sp" => "Scissors cut Paper.",
      "pr" => "Paper covers Rock.",
      "rl" => "Rock crushes Lizard.",
      "lk" => "Lizard poisons Spock.",
      "ks" => "Spock smashes Scissors.",
      "sl" => "Scissors decapitates Lizard.",
      "lp" => "Lizard eats Paper.",
      "pk" => "Paper disproves Spock.",
      "kr" => "Spock vaporizes Rock.",
      "rs" => "Rock crushes Scissors."
    }
  else
    OPTIONS = {
      "p" => "paper",
      "r" => "rock",
      "s" => "scissors"
    }

    WINNING_COMBINATIONS = {
      "sp" => "Scissors cut Paper.",
      "pr" => "Paper covers Rock.",
      "rs" => "Rock crushes Scissors."
    }
  end


  def initialize(value)
    unless OPTIONS.keys.include? value
      fail ArgumentError,
        "Unrecognized move value: '#{value}'. " +
        "Acceptable values: " +
        OPTIONS.keys.join(", ") + "."
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

  def opposites
    OPTIONS.keys.select {|e| Move.new(e) > self }
  end

  def self.prompt
    opts = OPTIONS.map { |k,v| v.sub(k, "(#{k.capitalize})") }
    opts[0..-2].join(", ") + " or " + opts[-1] + "?"
  end

  def self.result_str(move1, move2)
    WINNING_COMBINATIONS["#{move1}#{move2}"]
  end
end

# Play the game

PRS.new.play
