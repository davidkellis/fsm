require 'set'
require 'nfa'
require 'dfa'

# Most of the machines constructed here are based
# on section 2.5 of the Ragel User Guide (http://www.complang.org/ragel/ragel-guide-6.6.pdf)

module FSA
  module Builder
    ############### The following methods create FSAs given a stream of input tokens #################
    
    def literal(token_stream, alphabet = DEFAULT_ALPHABET)
      start = current_state = State.new
      nfa = NFA.new(start, [], alphabet)
      token_stream.each do |token|
        next_state = State.new
        nfa.add_transition(token, current_state, next_state)
        current_state = next_state
      end
      current_state.final = true
      nfa.update_final_states
      nfa
    end
    
    def any(token_collection, alphabet = DEFAULT_ALPHABET)
      start = State.new
      nfa = NFA.new(start, [], alphabet)
      final = State.new(true)
      token_collection.each {|token| nfa.add_transition(token, start, final) }
      nfa.update_final_states
      nfa
    end
    
    def dot(alphabet = DEFAULT_ALPHABET)
      any(alphabet)
    end
    
    # This implements a character class, and is specifically for use with matching strings
    def range(c_begin, c_end)
      any((c_begin..c_end).to_a)
    end
    
    ############### The following methods create FSAs given other FSAs #################
    
    # Append b onto a
    # Appending produces a machine that matches all the strings in machine a 
    # followed by all the strings in machine b.
    # This differs from concat in that the composite machine's final states are the union of machine a's final states
    # and machine b's final states.
    def append(a, b)
      a = a.deep_clone
      b = b.deep_clone
      
      # add an epsilon transition from each final state of machine a to the start state of maachine b.
      # then mark each of a's final states as not final
      a.final_states.each do |final_state|
        a.add_transition(:epsilon, final_state, b.start_state)
      end
      
      # add all of machine b's transitions to machine a
      b.transitions.each {|t| a.add_transition(t.token, t.from, t.to) }
      a.final_states = a.final_states | b.final_states
      a.alphabet = a.alphabet | b.alphabet
      
      a
    end
    
    # Concatenate b onto a
    # Concatenation produces a machine that matches all the strings in machine a 
    # followed by all the strings in machine b.
    # This differs from append in that the composite machine's final states are the set of final states
    # taken from machine b.
    def concat(a, b)
      a = a.deep_clone
      b = b.deep_clone
      
      # add an epsilon transition from each final state of machine a to the start state of maachine b.
      # then mark each of a's final states as not final
      a.final_states.each do |final_state|
        a.add_transition(:epsilon, final_state, b.start_state)
        final_state.final = false
      end
      
      # add all of machine b's transitions to machine a
      b.transitions.each {|t| a.add_transition(t.token, t.from, t.to) }
      a.final_states = b.final_states
      a.alphabet = a.alphabet | b.alphabet
      
      a
    end
    
    def union(a, b)
      a = a.deep_clone
      b = b.deep_clone
      start = State.new
      nfa = NFA.new(start, [], a.alphabet | b.alphabet)
      
      # add epsilon transitions from the start state of the new machine to the start state of machines a and b
      nfa.add_transition(:epsilon, start, a.start_state)
      nfa.add_transition(:epsilon, start, b.start_state)
      
      # add all of a's and b's transitions to the new machine
      (a.transitions + b.transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      nfa.update_final_states
      
      nfa
    end
    
    def kleene(machine)
      machine = machine.deep_clone
      start = State.new
      final = State.new(true)
      
      nfa = NFA.new(start, [], machine.alphabet)
      nfa.add_transition(:epsilon, start, final)
      nfa.add_transition(:epsilon, start, machine.start_state)
      machine.final_states.each do |final_state|
        nfa.add_transition(:epsilon, final_state, start)
        final_state.final = false
      end
      
      # add all of machine's transitions to the new machine
      (machine.transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      nfa.update_final_states
      
      nfa
    end
    
    def plus(machine)
      concat(machine, kleene(machine))
    end
    
    def optional(machine)
      union(machine, NFA.new(State.new(true), [], Set.new(machine.alphabet)))
    end
    
    def repeat(machine, min, max = nil)
      max ||= min
      m = NFA.new(State.new(true), [], Set.new(machine.alphabet))
      min.times { m = concat(m, machine) }
      (max - min).times { m = append(m, machine) }
      m
    end
    
    def negate(machine)
      # difference(kleene(any(alphabet)), machine)
      machine = machine.to_dfa
      
      # invert the final flag of every state
      machine.states.each {|state| state.final = !state.final? }
      machine.update_final_states
      
      machine.to_nfa
    end
    
    # a - b == a && !b
    def difference(a, b)
      intersection(a, negate(b))
    end
    
    # By De Morgan's Law: !(!a || !b) = a && b
    def intersection(a, b)
      negate(union(negate(a), negate(b)))
    end
  end
end
