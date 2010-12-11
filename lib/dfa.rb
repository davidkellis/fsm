require 'nfa'

module FSA
  class DFA < NFA
    # DFA reuses @current_states but treats it as a single DFAState object instead of an array of NFAState objects.
  
    # This is an implementation of the "Reducing a DFA to a Minimal DFA" algorithm presented here: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart4.pdf
    # An implementation of Hopcroft's algorithm.
    def minimize!
    end
  
    def reset
      @current_states = @start_state
    end
  
    def <<(input_symbol)
      @current_states = @current_states.next_state(input_symbol)
    end
  
    def accept?
      @current_states.final?
    end
  
    def dup
      DFA.new(@start_state.dup, nil, @alphabet.dup)
    end
  end

  class DFAState < State
    attr_accessor :constituent_states     # This holds a list of state ids that form a state-set in an NFA. This DFAState represents that state-set.
  
    def initialize(final = false, id = nil, constituent_states = [])
      super(final, id)
      @constituent_states = constituent_states
    end
  
    def clone
      DFAState.new(@final, @id, @constituent_states)
    end
  
    def next_state(input)
      possible_transitions = transitions.select { |t| t.accept?(input) }        # Filter the outbound transitions, selecting only the one that accepts the input.
      case possible_transitions.length
        when 0
          raise "DFA is not complete."                                          # no next state
        when 1 
          possible_transitions.first.dest_state                                 # Determine the next state, given the input.
        else
          raise "FSA is not deterministic."                                     # multiple next states are possible
      end
    end
  end
end