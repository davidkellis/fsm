require 'set'
require 'nfa'
require 'dfa'

# Most of the machines constructed here are based
# on section 2.5 of the Ragel User Guide (http://www.complang.org/ragel/ragel-guide-6.6.pdf)

module FSA
  module Builder
    ############### The following methods create FSAs given a stream of input tokens #################
    
    def literal(token_stream)
      start = current_state = State.new
      nfa = NFA.new(start)
      token_stream.each do |token|
        next_state = State.new
        nfa.add_transition(token, current_state, next_state)
        current_state = next_state
      end
      current_state.final = true
      nfa
    end
    
    def any(token_stream)
      start = State.new
      nfa = NFA.new(start)
      final = State.new(true)
      token_stream.each {|token| nfa.add_transition(token, start, final) }
      nfa
    end
    
    # def range(c_begin, c_end)
    #   any((c_begin..c_end).to_a)
    # end
    
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
      
      a
    end
    
    def union(a, b)
      a = a.deep_clone
      b = b.deep_clone
      start = State.new
      nfa = NFA.new(start)
      
      # add epsilon transitions from the start state of the new machine to the start state of machines a and b
      nfa.add_transition(:epsilon, start, a.start_state)
      nfa.add_transition(:epsilon, start, b.start_state)
      
      # add all of a's and b's transitions to the new machine
      (a.transitions + b.transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      
      nfa
    end
    
    def kleene(machine)
      machine = machine.deep_clone
      start = State.new
      final = State.new(true)
      
      nfa = NFA.new(start)
      nfa.add_transition(:epsilon, start, final)
      nfa.add_transition(:epsilon, start, machine.start_state)
      machine.final_states.each do |final_state|
        nfa.add_transition(:epsilon, final_state, start)
        final_state.final = false
      end
      
      # add all of machine's transitions to the new machine
      (machine.transitions).each {|t| nfa.add_transition(t.token, t.from, t.to) }
      
      nfa
    end
    
    def plus(machine)
      concat(machine, kleene(machine))
    end
    
    def optional(machine)
      union(machine, NFA.new(State.new(true)))
    end
    
    def repeat(machine, min, max = nil)
      max ||= min
      m = NFA.new(State.new(true))
      min.times { m = concat(m, machine) }
      (max - min).times { m = append(m, machine) }
      m
    end
    
    def not(machine, alphabet = :implicit)
      machine
    end
    
    # From Ragel Guide:
    #  The diﬀerence operation produces a machine that matches strings that are in machine one 
    #  but are not in machine two. To achieve subtraction, a union is performed on the two machines. 
    #  After the result has been made deterministic, any ﬁnal state that came from machine two or is a 
    #  combination of states involving a ﬁnal state from machine two has its ﬁnal state status revoked. 
    #  As with intersection, the operation is completed by pruning any path that does not lead to a ﬁnal 
    #  state.
    def difference(a, b, alphabet = :implicit)
      union_dfa = union(a, b).to_dfa(alphabet)                                  # perform union and make deterministic
      # reject final states that came from machine two 
      # or is a combination of states involving a final state from machine two
      reject_states = union_dfa.final_states.select do |composite_state|
        (composite_state.constituent_states & b.final_states.map(&:id)).length > 0    # there is a non-empty set intersection
      end
      reject_states.each { |s| s.final = false }
      union_dfa.final_states = union_dfa.final_states - reject_states
      # TODO: prune paths that don't lead to final state
      union_dfa
    end
    
    # From Ragel Guide:
    #  Intersection produces a machine that matches any string that is in both machine one and machine two.
    #  To achieve intersection, a union is performed on the two machines. After the result 
    #  has been made deterministic, any ﬁnal state that is not a combination of ﬁnal states from both 
    #  machines has its ﬁnal state status revoked. To complete the operation, paths that do not lead to 
    #  a ﬁnal state are pruned from the machine. Therefore, if there are any such paths in either of the 
    #  expressions they will be removed by the intersection operator.
    def intersection(a, b, alphabet = :implicit)
      union_dfa = union(a, b).to_dfa(alphabet)                                  # perform union and make deterministic
      intersection = union_dfa.final_states.select do |cs|                      # select intersection final states
        (cs.constituent_states & a.final_states.map(&:id)).length > 0 && (cs.constituent_states & b.final_states.map(&:id)).length > 0
      end
      (union_dfa.final_states - intersection).each { |s| s.final = false }
      union_dfa.final_states = intersection
      # TODO: prune paths that don't lead to final state
      union_dfa
    end
  end
end
