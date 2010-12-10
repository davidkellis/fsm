require 'set'
# require 'dfa'

# hack
class String
  def each(*args, &blk)
    each_char(*args, &blk)
  end
end

module FSA
  class NFA
    attr_accessor :alphabet
    attr_accessor :states
    attr_accessor :start_state
    attr_accessor :transitions
    attr_accessor :final_states
    
    def initialize(alphabet, states, start_state)
      @alphabet = alphabet
      @states = states
      @start_state = start_state
      @transitions = []
      update_final_states
      reset_current_states
    end
    
    def update_final_states
      @final_states = @states.select { |s| s.final? }
    end
    
    def reset_current_states
      @current_states = epsilon_closure([@start_state])
    end
    
    def add_transition(event, from_state, to_state)
      t = Transition.new(event, from_state, to_state)
      @transitions << t
      t
    end
    
    def match?(input)
      reset_current_states
      
      input.each do |token|
        self << token
      end
      
      accept?
    end
    
    # process another input token
    def <<(input_token)
      @current_states = next_states(@current_states, input_token)
    end
    
    def accept?
      @current_states.any? { |s| s.final? }
    end
    
    def next_states(state_set, input_token)
      # Retrieve a list of states in the epsilon closure of the given state set
      epsilon_reachable_states = epsilon_closure(state_set)
      
      # Build an array of outbound transitions from each state in the epsilon-closure
      # Filter the outbound transitions, selecting only those that accept the input we are given.
      outbound_transitions = @transitions.select {|t| epsilon_reachable_states.include?(t.from) && t.accept?(input_token) }
      
      # Build an array of epsilon-closures of each transition's destination state.
      destination_state_epsilon_closures = outbound_transitions.map { |t| epsilon_closure([t.to]) }
      
      # Union each of the epsilon-closures (each is an array) together to form a flat array of states in the epsilon-closure of all of our current states.
      next_states = destination_state_epsilon_closures.reduce { |combined_state_set, individual_state_set| combined_state_set.merge(individual_state_set) }
      
      next_states || Set.new
    end

    # Determine the epsilon closure of the given state set
    # That is, determine what states are reachable on an epsilon transition from the current state set (@current_states).
    # Returns a Set of State objects.
    def epsilon_closure(state_set)
      visited_states = Set.new()
      unvisited_states = state_set
      begin
        epsilon_transitions = @transitions.select { |t| t.accept?(Transition::Epsilon) && unvisited_states.include?(t.from) }
        destination_states = epsilon_transitions.map(&:to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end until unvisited_states.empty?
      visited_states
    end
    
    
    
    
    
    # This is an implementation of the "Algorithm: Convert NFA to DFA" presented here: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart3.pdf
    # An implementation of the subset construction algorithm.
    def dfa_state_chart(alphabet = :implicit)
      alphabet = implicit_alphabet if alphabet == :implicit
      dfa_states = Hash.new
      unprocessed_states = Array.new
      
      # push a new set of states onto the unprocessed states queue. The set of states is the epsilon closure of the start state of the NFA.
      unprocessed_states.push @start_state.epsilon_closure([], false).to_set
      until unprocessed_states.empty?
        ss = unprocessed_states.shift                         # retrieve and remove the first state set from the queue
        dfa_transitions = (dfa_states[ss] ||= Hash.new)       # retrieve the transition table for the given set of states, ss.
        alphabet.each do |symbol|
          # set of transitions that accept 'symbol', which lead away any/all states in ss
          transitions = ss.reduce([]) { |memo, state| memo |= state.transitions.select { |t| t.accept?(symbol) } }
          
          # set of destination states connected to each symbol in set of transitions from above
          destination_states = transitions.reduce(Set.new) { |m, t| m.add t.dest_state }
          
          # this is the epsilon closure over the set of destinations states connected to the set of transitions from above.
          epsilon_closures = destination_states.reduce([]) { |m, s| m |= s.epsilon_closure([], false) }
          
          dfa_transitions[symbol] = epsilon_closures.to_set
          unprocessed_states.push(dfa_transitions[symbol]) if dfa_states[dfa_transitions[symbol]].nil?    # add the epsilon closure as a new state if it hasn't already been added
        end
      end
      
      dfa_states
    end
    
    def to_dfa(alphabet = :implicit)
      composite_states = Hash.new
      alphabet = implicit_alphabet if alphabet == :implicit
      state_chart = dfa_state_chart(alphabet)
      
      error_state = DFAState.new
      alphabet.each { |symbol| error_state.transition(symbol, error_state) }
      
      # Create all the new composite DFA states
      for ss in state_chart.keys
        final = ss.any? { |s| s.final? }
        composite_states[ss] = DFAState.new(final, nil, ss.map(&:id).to_a)
      end
      
      # Create all the transitions between the composite DFA states
      state_chart.each do |source_ss, transitions|
        transitions.each do |symbol, dest_ss|
          composite_states[source_ss].transition(symbol, composite_states[dest_ss])
        end
        
        # if there is a symbol in alphabet that isn't accounted for in the transition table, then transition to the error state on that symbol
        (alphabet - transitions.keys).each do |symbol|
          composite_states[source_ss].transition(symbol, error_state)
        end
      end
      
      start_state = composite_states[@start_state.epsilon_closure([], false).to_set]
      DFA.new(start_state, nil, alphabet)
    end
    
    
    
    def reachable_states(states = [])
      unless states.include?(self)
        states << self
        @transitions.each { |t| t.dest_state.reachable_states(states) }
      end
      states
    end

    def reachable_transitions
      reachable_states.reduce([]) { |memo, s| memo |= s.transitions }
    end

    def epsilon_transition(*dest_states)
      for dest_state in dest_states
        @transitions << Transition.new(Transition::Epsilon, dest_state)
      end
      self
    end

  end
  
  class State
    def self.next_id
      @@next_id += 1
    end

    attr_reader :id
    attr_writer :final

    @@next_id = 0

    def initialize(final = false, id = nil)
      @id = id || State.next_id
      @final = final
    end

    def final?
      @final
    end
  end

  class Transition
    Epsilon = :epsilon
    
    attr_reader :event
    attr_reader :from
    attr_reader :to
    
    def initialize(event, from_state, to_state)
      @event = event
      @from = from_state
      @to = to_state
    end
    
    def accept?(input)
      @event == input
    end
  end
end

def main
  # create some states with which to manually construct an NFA
  start = FSA::State.new
  a = FSA::State.new
  b1 = FSA::State.new
  b2 = FSA::State.new
  c = FSA::State.new(true)
  
  # build an NFA to match "abbc"
  nfa = FSA::NFA.new(['a', 'b', 'c'], [start, a, b1, b2, c], start)
  nfa.add_transition('a', start, a)
  nfa.add_transition('b', a, b1)
  nfa.add_transition('b', b1, b2)
  nfa.add_transition('c', b2, c)
  
  # run the DFA
  puts "nfa.match?(\"abc\") = #{nfa.match?("abc")}"
  puts "nfa.match?(\"\") = #{nfa.match?("")}"
  puts "nfa.match?(\"abbcc\") = #{nfa.match?("abbcc")}"
  puts "nfa.match?(\"abbc\") = #{nfa.match?("abbc")}"
end

main if __FILE__ == $0