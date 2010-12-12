require 'set'
require 'dfa'

# hack
class String
  def each(*args, &blk)
    each_char(*args, &blk)
  end
end

module FSA
  DEFAULT_ALPHABET = ((' '..'~').to_a + ["\n"] + ["\t"]).to_set
  
  class NFA
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
      reset_current_states
    end
    
    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&:dup)
      state_mapping = Hash[old_states.zip(new_states)]
      new_transitions = @transitions.map {|t| Transition.new(t.token, state_mapping[t.from], state_mapping[t.to]) }
      
      NFA.new(state_mapping[@start_state], new_transitions, Set.new(@alphabet))
    end
    
    def update_final_states
      @final_states = @states.select { |s| s.final? }.to_set
    end
    
    def reset_current_states
      @current_states = epsilon_closure([@start_state])
    end
    
    def add_transition(token, from_state, to_state)
      @alphabet << token      # alphabet is a set, so there will be no duplications
      @states << to_state     # states is a set, so there will be no duplications (to_state should be the only new state)
      t = Transition.new(token, from_state, to_state)
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

    # This implements the subset construction algorithm presented on page 118 of the first edition of the dragon book.
    # I found a similar explanation at: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart3.pdf
    def to_dfa
      state_map = Hash.new            # this map contains nfa_state_set => dfa_state pairs
      dfa_transitions = []
      dfa_alphabet = Set.new(@alphabet) - Set[:epsilon]
      visited_state_sets = Set.new()
      nfa_start_state_set = epsilon_closure([@start_state])
      unvisited_state_sets = Set[nfa_start_state_set]
      until unvisited_state_sets.empty?
        # take one of the unvisited state sets
        state_set = unvisited_state_sets.first
        unvisited_state_sets.delete(state_set)

        # this new DFA state, new_dfa_state, represents the nfa state set, state_set
        new_dfa_state = State.new(state_set.any?(&:final?))
        
        # add the mapping from nfa state set => dfa state
        state_map[state_set] = new_dfa_state
        
        # Figure out the set of next-states for each token in the alphabet
        # Add each set of next-states to unvisited_state_sets
        dfa_alphabet.each do |token|
          next_nfa_state_set = next_states(state_set, token)
          unvisited_state_sets << next_nfa_state_set
          # add a transition from new_dfa_state -> next_nfa_state_set
          # next_nfa_state_set is a placeholder that I'll go back and replace with the corresponding dfa_state
          # I don't insert the dfa_state yet, because it hasn't been created yet
          dfa_transitions << Transition.new(token, new_dfa_state, next_nfa_state_set)
        end
        
        visited_state_sets << state_set
        unvisited_state_sets = unvisited_state_sets - visited_state_sets
      end
      
      # replace the nfa_state_set currently stored in each transition's "to" field with the
      # corresponding dfa state.
      dfa_transitions.each {|transition| transition.to = state_map[transition.to] }
      
      DFA.new(state_map[nfa_start_state_set], dfa_transitions, dfa_alphabet)
    end
    
    # def traverse
    #   visited_states = Set.new()
    #   unvisited_states = Set[@start_state]
    #   begin
    #     state = unvisited_states.shift
    #     outbound_transitions = @transitions.select { |t| t.from == state }
    #     outbound_transitions.each {|t| yield t }
    #     destination_states = outbound_transitions.map(&:to).to_set
    #     visited_states << state
    #     unvisited_states = (unvisited_states | destination_states) - visited_states
    #   end until unvisited_states.empty?
    #   nil
    # end
    
    def graphviz
      retval = "digraph G { "
      @transitions.each do |t|
        retval += "#{t.from.id} -> #{t.to.id} [label=\"#{t.token}\"];"
      end
      @final_states.each do |s|
        retval += "#{s.id} [color=lightblue2, style=filled, shape=doublecircle];"
      end
      retval += " }"
      retval
    end
  end
  
  class State
    def self.next_id
      @@next_id += 1
    end

    attr_reader :id
    attr_accessor :final

    @@next_id = 0

    def initialize(final = false, id = nil)
      @id = id || State.next_id
      @final = final
    end

    def final?
      @final
    end
    
    def dup
      State.new(@final)
    end
  end

  class Transition
    Epsilon = :epsilon
    
    attr_accessor :token
    attr_accessor :from
    attr_accessor :to
    
    def initialize(token, from_state, to_state)
      @token = token
      @from = from_state
      @to = to_state
    end
    
    def accept?(input)
      @token == input
    end
  end
end
