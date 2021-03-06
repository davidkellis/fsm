require 'nfa'

module FSA
  class DFA
    attr_accessor :alphabet
    attr_accessor :states
    attr_accessor :start_state
    attr_accessor :transitions
    attr_accessor :final_states
    
    def initialize(start_state, transitions = [], alphabet = DEFAULT_ALPHABET)
      @start_state = start_state
      @transitions = transitions
      
      @alphabet = Set.new(alphabet)
      @alphabet.merge(@transitions.map(&:token))
      
      @states = reachable_states
      update_final_states
      reset_current_state
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&:dup)
      state_mapping = Hash[old_states.zip(new_states)]
      new_transitions = @transitions.map {|t| Transition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      
      DFA.new(state_mapping[@start_state], new_transitions, Set.new(@alphabet))
    end
    
    def update_final_states
      @final_states = @states.select { |s| s.final? }.to_set
    end
    
    def reset_current_state
      @current_state = @start_state
    end
    
    def add_transition(token, from_state, to_state)
      @alphabet << token      # alphabet is a set, so there will be no duplications
      @states << to_state     # states is a set, so there will be no duplications (to_state should be the only new state)
      t = Transition.new(token, from_state, to_state)
      @transitions << t
      t
    end
    
    def match?(input)
      reset_current_state
      
      input.each do |token|
        self << token
      end
      
      accept?
    end
    
    # Returns an array of matches found in the input string, each of which begins at the offset input_start_offset
    def matches_at_offset(input, input_start_offset)
      reset_current_state

      matches = []
      (input_start_offset...input.length).each do |offset|
        token = input[offset]
        self << token
        matches << MatchRef.new(input, input_start_offset..offset) if accept?
      end
      matches
    end
    
    # Returns an array of matches found anywhere in the input string
    def matches(input)
      (0...input.length).reduce([]) do |memo, offset|
        memo + matches_at_offset(input, offset)
      end
    end
    
    # process another input token
    def <<(input_token)
      @current_state = next_state(@current_state, input_token)
    end
    
    def accept?
      @current_state.final?
    end
    
    def next_state(state, input_token)
      t = @transitions.find {|t| state == t.from && t.accept?(input_token) }
      t.to
    end

    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states
      visited_states = Set.new()
      unvisited_states = Set[@start_state]
      begin
        outbound_transitions = @transitions.select { |t| unvisited_states.include?(t.from) }
        destination_states = outbound_transitions.map(&:to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end until unvisited_states.empty?
      visited_states
    end
    
    def to_nfa
      dfa = self.deep_clone
      NFA.new(dfa.start_state, dfa.transitions, Set.new(dfa.alphabet))
      # # add all of this machine's transitions to the new machine
      # @transitions.each {|t| nfa.add_transition(t.token, t.from, t.to) }
      # nfa
    end
    
    # This is an implementation of the "Reducing a DFA to a Minimal DFA" algorithm presented here: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart4.pdf
    # This implements Hopcroft's algorithm as presented on page 142 of the first edition of the dragon book.
    def minimize!
      # I'll implement this when I need it
    end
  end
end