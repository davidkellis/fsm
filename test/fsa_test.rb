$: << File.join(File.dirname(File.expand_path(__FILE__)), "..", "lib")
require 'test/unit'
require "fsa"
require "nfa"
require "dfa"

class FSATest < Test::Unit::TestCase
  include FSA::Builder
  
  def build_nfa_machines
    @a = literal('a')
    @b = literal('b')
    @c = literal('c')
    @d = literal('d')
    @n = literal('n')
    @y = literal('y')
    @z = literal('z')
    
    @m1 = concat(@a, @b)                                         # ab
    @m2 = union(concat(@a, @b), concat(@y, @z))                  # ab|yz
    @m3 = concat(concat(@a, kleene(union(@b, @c))), @d)          # a(b|c)*d
    @m4 = plus(@m1)                                              # (ab)+
    @m5 = concat(@b, concat(repeat(concat(@a, @n), 2), @a))      # b(an){2}a
    @m6 = repeat(@a, 4, 6)                                       # a{4,6}
    # @m7 = difference(plus(range('a', 'z')), literal('int'))      # [a-z]+ - 'int'
    
    # The following two machines match C-style comments. I'm not quite sure how they differ.
    # @m8 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), concat(concat(kleene(any('blah*/ ')), literal('*/')), kleene(any('blah*/ '))))), literal('*/'))
    #@m9 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), literal('*/'))), literal('*/'))
    #@m9 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), concat(concat(kleene(any('blah*/ ')), literal('*/')), kleene(any('blah*/ '))))), literal('*/')).to_dfa
    #@m9 = concat(concat(literal('/*'), difference(kleene(any('blah*/ ')), intersection(kleene(any('blah*/ ')), literal('*/')) )), literal('*/'))
    
    # @m10 = difference(kleene(any('abcdefg')), concat(concat(kleene(any('abcdefg')), literal('de')), kleene(any('abcdefg'))))
    # @m11 = concat(difference(kleene(any('abcdefg')), concat(concat(kleene(any('abcdefg')), literal('ab')), kleene(any('abcdefg')))), literal('aa'))
  end
  
  def build_dfa_machines
    build_nfa_machines
    
    @a = @a.to_dfa
    @b = @b.to_dfa
    @c = @c.to_dfa
    @d = @d.to_dfa
    @n = @n.to_dfa
    @y = @y.to_dfa
    @z = @z.to_dfa
    
    @m1 = @m1.to_dfa
    @m2 = @m2.to_dfa
    @m3 = @m3.to_dfa
    @m4 = @m4.to_dfa
    @m5 = @m5.to_dfa
    @m6 = @m6.to_dfa
    # @m7 = @m7.to_dfa
    # @m8 = @m8.to_dfa
    # @m9 = @m9.to_dfa
    # @m10 = @m10.to_dfa
    # @m11 = @m11.to_dfa
  end
  
  def test_nfa_builder
    build_nfa_machines
    run_assertions
  end

  def test_dfa_builder
    build_dfa_machines
    run_assertions
  end
  
  def run_assertions
    assert @a.match?('a')
    assert @m1.match?('ab')
    assert !@m1.match?('a')
    assert !@m1.match?('aab')
    assert !@m1.match?('abb')
    assert @m2.match?('ab')
    assert @m2.match?('yz')
    assert !@m2.match?('abb')
    assert !@m2.match?('aab')
    assert !@m2.match?('abyz')
    assert !@m2.match?('y')
    assert !@m2.match?('a')
    assert @m3.match?('abbbbbbd')
    assert @m3.match?('abcccbbd')
    assert @m3.match?('abcbcd')
    assert @m3.match?('abcd')
    assert @m3.match?('acbd')
    assert @m3.match?('abd')
    assert @m3.match?('acd')
    assert @m3.match?('ad')
    assert !@m3.match?('aabbbd')
    assert !@m3.match?('add')
    assert @m4.match?('ab')
    assert @m4.match?('abab')
    assert !@m4.match?('aba')
    assert !@m4.match?('ababb')
    assert @m5.match?('banana')
    assert !@m5.match?('banan')
    assert @m6.match?('aaaa')
    assert @m6.match?('aaaaaa')
    assert !@m6.match?('aaa')
    assert !@m6.match?('aaaaaaa')
    # assert @m7.match?('abc')
    # assert @m7.match?('integer')
    # assert !@m7.match?('int')
    # assert @m8.match?('/* blah blah blah */')
    # assert @m8.match?('/* blah * / * // blah ***** blah */')
    # assert @m8.match?('/**/')
    # assert !@m8.match?('/* blah * / * // blah ***** blah **/ */')
    # assert !@m8.match?('/* blah * / * // blah ***** blah */ /')
    # assert @m10.match?('')
    # assert @m10.match?('ed')
    # assert @m10.match?('aaaabdddddceeeddddgfecbabca')
    # assert !@m10.match?('de')
    # assert !@m10.match?('edde')
    # assert !@m10.match?('deed')
    # assert !@m10.match?('aadeaa')
    # assert !@m10.match?('deaaaa')
    # assert !@m10.match?('aaaade')
    # assert @m11.match?('acdaa')
    # assert @m11.match?('bbaa')
    # assert !@m11.match?('aabaa')
  end
end