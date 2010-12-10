require 'set'
require 'nfa'
require 'dfa'

module FSA
  module FSABuilder
    ############### The following methods create FSAs given Strings #################
    
    def literal(str)
      start = current_state = NFAState.new
      str.each_char do |c|
        next_state = NFAState.new
        current_state.transition(c, next_state)
        current_state = next_state
      end
      current_state.final = true
      NFA.new(start)
    end
    
    def any(char_array_or_string)
      start = NFAState.new
      final = NFAState.new(true)
      enum = case char_array_or_string
        when String
          char_array_or_string.each_char
        when Array
          char_array_or_string.each
      end
      enum.each { |c| start.transition(c, final) }
      NFA.new(start)
    end
    
    def range(c_begin, c_end)
      any((c_begin..c_end).to_a)
    end
    
    ############### The following methods create FSAs given other FSAs #################
    
    # append b onto a
    def append(a, b)
      a = a.dup if a.ro?
      b = b.dup if b.ro?
      a.final_states.each { |s| s.epsilon_transition(b.start_state) }
      a.final_states |= b.final_states
      a
    end
    
    #concatenate b onto a
    def concat(a, b)
      a = a.dup if a.ro?
      b = b.dup if b.ro?
      a.final_states.each { |s| s.epsilon_transition(b.start_state) ; s.final = false }
      a.final_states = b.final_states
      a
    end
    
    def union(a, b)
      a = a.dup if a.ro?
      b = b.dup if b.ro?
      start = NFAState.new.epsilon_transition(a.start_state, b.start_state)
      m = NFA.new(start, a.final_states | b.final_states)
      m
    end
    
    def kleene(machine)
      machine = machine.dup if machine.ro?
      a,b,c,d = 4.times.map { NFAState.new }
      d.final = true
      a.epsilon_transition(b, d)
      b.epsilon_transition(machine.start_state)
      machine.final_states.each { |s| s.epsilon_transition(c) ; s.final = false }
      c.epsilon_transition(b, d)
      NFA.new(a, [d])
    end
    
    def plus(machine)
      #machine = machine.dup if machine.ro?
      concat(machine, kleene(machine))
    end
    
    def optional(machine)
      #machine = machine.dup if machine.ro?
      union(machine, NFA.new(NFAState.new(true)))
    end
    
    def repeat(machine, min, max = nil)
      max ||= min
      m = NFA.new(NFAState.new(true))
      min.times { m = concat(m, machine.dup) }
      (max - min).times { m = append(m, machine.dup) }
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

def main
  a = literal('a').ro!
  b = literal('b').ro!
  c = literal('c').ro!
  d = literal('d').ro!
  n = literal('n').ro!
  y = literal('y').ro!
  z = literal('z').ro!
  
  m1 = concat(a, b).ro!                                   # ab
  m2 = union(concat(a, b), concat(y, z)).ro!              # ab|yz
  m3 = concat(concat(a, kleene(union(b, c))), d).ro!      # a(b|c)*d
  m4 = plus(m1).ro!                                       # (ab)+
  m5 = concat(b, concat(repeat(concat(a, n), 2), a)).ro!  # b(an){2}a
  m6 = repeat(a, 4, 6).ro!                                # a{4,6}
  m7 = difference(plus(range('a', 'z')), literal('int')).ro!    # [a-z]+ - 'int'
  
  # The following two machines match C-style comments. I'm not quite sure how they differ.
  m8 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), concat(concat(kleene(any('blah*/ ')), literal('*/')), kleene(any('blah*/ '))))), literal('*/'))
  #m9 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), literal('*/'))), literal('*/'))
  #m9 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), concat(concat(kleene(any('blah*/ ')), literal('*/')), kleene(any('blah*/ '))))), literal('*/')).to_dfa
  #m9 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), intersection(kleene(any('blah*/ ')), literal('*/')) )), literal('*/'))
  
  m10 = difference(kleene(any('abcdefg')), concat(concat(kleene(any('abcdefg')), literal('de')), kleene(any('abcdefg'))))
  m11 = concat(difference(kleene(any('abcdefg')), concat(concat(kleene(any('abcdefg')), literal('ab')), kleene(any('abcdefg')))), literal('aa'))
  
  assert a.match?('a')
  assert m1.match?('ab')
  assert !m1.match?('a')
  assert !m1.match?('aab')
  assert !m1.match?('abb')
  assert m2.match?('ab')
  assert m2.match?('yz')
  assert !m2.match?('abb')
  assert !m2.match?('aab')
  assert !m2.match?('abyz')
  assert !m2.match?('y')
  assert !m2.match?('a')
  assert m3.match?('abbbbbbd')
  assert m3.match?('abcccbbd')
  assert m3.match?('abcbcd')
  assert m3.match?('abcd')
  assert m3.match?('acbd')
  assert m3.match?('abd')
  assert m3.match?('acd')
  assert m3.match?('ad')
  assert !m3.match?('aabbbd')
  assert !m3.match?('add')
  assert m4.match?('ab')
  assert m4.match?('abab')
  assert !m4.match?('aba')
  assert !m4.match?('ababb')
  assert m5.match?('banana')
  assert !m5.match?('banan')
  assert m6.match?('aaaa')
  assert m6.match?('aaaaaa')
  assert !m6.match?('aaa')
  assert !m6.match?('aaaaaaa')
  assert m7.match?('abc')
  assert m7.match?('integer')
  assert !m7.match?('int')
  assert m8.match?('/* blah blah blah */')
  assert m8.match?('/* blah * / * // blah ***** blah */')
  assert m8.match?('/**/')
  assert !m8.match?('/* blah * / * // blah ***** blah **/ */')
  assert !m8.match?('/* blah * / * // blah ***** blah */ /')
  assert m10.match?('')
  assert m10.match?('ed')
  assert m10.match?('aaaabdddddceeeddddgfecbabca')
  assert !m10.match?('de')
  assert !m10.match?('edde')
  assert !m10.match?('deed')
  assert !m10.match?('aadeaa')
  assert !m10.match?('deaaaa')
  assert !m10.match?('aaaade')
  assert m11.match?('acdaa')
  assert m11.match?('bbaa')
  assert !m11.match?('aabaa')
end