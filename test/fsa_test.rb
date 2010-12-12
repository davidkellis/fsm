$: << File.join(File.dirname(File.expand_path(__FILE__)), "..", "lib")
require 'test/unit'
require "fsa"
require "nfa"
require "dfa"

class FSATest < Test::Unit::TestCase
  include FSA::Builder
  
  def build_nfa_machines
    simple_alphabet = (('a'..'z').to_a + ['*', '/', ' ']).to_set
    
    @a = literal('a', simple_alphabet)
    @b = literal('b', simple_alphabet)
    @c = literal('c', simple_alphabet)
    @d = literal('d', simple_alphabet)
    @n = literal('n', simple_alphabet)
    @y = literal('y', simple_alphabet)
    @z = literal('z', simple_alphabet)
    
    @m1 = concat(@a, @b)                                         # ab
    @m2 = union(concat(@a, @b), concat(@y, @z))                  # ab|yz
    @m3 = concat(concat(@a, kleene(union(@b, @c))), @d)          # a(b|c)*d
    @m4 = plus(@m1)                                              # (ab)+
    @m5 = concat(@b, concat(repeat(concat(@a, @n), 2), @a))      # b(an){2}a
    @m6 = repeat(@a, 4, 6)                                       # a{4,6}
    @m7 = difference(plus(range('a', 'z', simple_alphabet)), literal('int', simple_alphabet))      # [a-z]+ - 'int'
    
    # m8 is a C comment parser
    # The Ragel rule is:
    #   comment = '/*' ( ( any @comm )* - ( any* '*/' any* ) ) '*/';
    @m8 = concat(concat(literal('/*'),
                        difference(kleene(dot(simple_alphabet)),
                                          concat(kleene(dot(simple_alphabet)),
                                                 concat(literal('*/', simple_alphabet),
                                                        kleene(dot(simple_alphabet)))))),
                 literal('*/'))

    @m8a = concat(literal('/*'),
                  concat(difference(kleene(dot(simple_alphabet)),
                                           concat(kleene(dot(simple_alphabet)),
                                                  concat(literal('*/', simple_alphabet),
                                                         kleene(dot(simple_alphabet))))),
                         literal('*/')))

    
    # @m9 -> ( any* '*/' any* )
    @m9 = concat(kleene(dot(simple_alphabet)),
                 concat(literal('*/', simple_alphabet),
                        kleene(dot(simple_alphabet))))
    
    # @m9a -> ( .* - ( .* '*/' .* ) )
    @m9a = difference(kleene(dot(simple_alphabet)),
                      concat(kleene(dot(simple_alphabet)),
                             concat(literal('*/', simple_alphabet),
                                    kleene(dot(simple_alphabet)))))
    
    # @m9b -> '/*' ( .* - ( .* '*/' .* ) )
    @m9b = concat(literal('/*'), @m9a)
    
    # @m9c -> '/*' ( .* - ( .* '*/' .* ) ) '*/'
    @m9c = concat(@m9b, literal('*/'))
    
    # m10 implements this regular expression: [a-g]* - ([a-g]*de[a-g]*)
    @m10 = difference(kleene(any('abcdefg')),
                      concat(concat(kleene(any('abcdefg')),
                                    literal('de', simple_alphabet)), 
                             kleene(any('abcdefg'))))
    
    # @m11 -> ([a-g]* - ([a-g]*de[a-g]*)) 'aa'
    @m11 = concat(difference(kleene(any('abcdefg')),
                             concat(concat(kleene(any('abcdefg')),
                                           literal('de', simple_alphabet)),
                                    kleene(any('abcdefg')))),
                  literal('aa'))
    
    @m12 = negate(@m2)      # !(ab|yz)
    
    # puts @m7.graphviz
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
    @m7 = @m7.to_dfa
    @m8 = @m8.to_dfa
    @m8a = @m8a.to_dfa
    @m9 = @m9.to_dfa
    @m9a = @m9a.to_dfa
    @m9b = @m9b.to_dfa
    @m9c = @m9c.to_dfa
    @m10 = @m10.to_dfa
    @m11 = @m11.to_dfa
    @m12 = @m12.to_dfa
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
    assert @m7.match?('abc')
    assert @m7.match?('integer')
    assert !@m7.match?('int')

    assert @m8.match?('/* blah blah blah */')
    assert @m8.match?('/* blah * / * // blah ***** blah */')
    assert @m8.match?('/**/')
    assert !@m8.match?('/* blah * / * // blah ***** blah **/ */')
    assert !@m8.match?('/* blah * / * // blah ***** blah */ /')

    assert @m8a.match?('/* blah blah blah */')
    assert @m8a.match?('/* blah * / * // blah ***** blah */')
    assert @m8a.match?('/**/')
    assert !@m8a.match?('/* blah * / * // blah ***** blah **/ */')
    assert !@m8a.match?('/* blah * / * // blah ***** blah */ /')

    assert @m9.match?('*/')
    assert @m9.match?('*/abc')
    assert @m9.match?('abc*/')
    assert @m9.match?(' */ ')
    assert !@m9.match?('')
    assert !@m9.match?('abc')
    assert !@m9.match?('* /')
    assert !@m9.match?('*a/')
    assert !@m9.match?('/*')
    
    assert @m9a.match?('')
    assert @m9a.match?('abc')
    assert @m9a.match?('* /')
    assert @m9a.match?('*a/')
    assert @m9a.match?('/** /')
    assert !@m9a.match?('*/')
    assert !@m9a.match?('*/abc')
    assert !@m9a.match?('abc*/')
    assert !@m9a.match?(' */ ')

    assert @m9b.match?('/*')
    assert @m9b.match?('/*abc')
    assert @m9b.match?('/** /')
    assert @m9b.match?('/**a/')
    assert @m9b.match?('/* * /')
    assert !@m9b.match?('/**/')
    assert !@m9b.match?('/* */abc')
    assert !@m9b.match?('/*abc*/')
    assert !@m9b.match?('/* */ ')

    assert @m9c.match?('/* blah blah blah */')
    assert @m9c.match?('/* blah * / * // blah ***** blah */')
    assert @m9c.match?('/**/')
    assert @m9c.match?('/* * */')
    assert !@m9c.match?('/* blah * / * // blah ***** blah **/ */')
    assert !@m9c.match?('/* blah * / * // blah ***** blah */ /')
    
    assert @m10.match?('')
    assert @m10.match?('ed')
    assert @m10.match?('aaaabdddddceeeddddgfecbabca')
    assert !@m10.match?('de')
    assert !@m10.match?('edde')
    assert !@m10.match?('deed')
    assert !@m10.match?('aadeaa')
    assert !@m10.match?('deaaaa')
    assert !@m10.match?('aaaade')
    
    assert @m11.match?('acdaa')
    assert @m11.match?('bbaa')
    assert @m11.match?('aa')
    assert @m11.match?('edaa')
    assert @m11.match?('aaaabdddddceeeddddgfecbabcaa')
    assert @m11.match?('aabaa')
    assert !@m11.match?('deaa')
    assert !@m11.match?('eddeaa')
    assert !@m11.match?('deedaa')
    assert !@m11.match?('aadeaa')
    assert !@m11.match?('deaaaa')
    assert !@m11.match?('aaaade')
    
    assert !@m12.match?("ab")
    assert !@m12.match?("yz")
    assert @m12.match?("")
    assert @m12.match?("a")
    assert @m12.match?("abc")
    assert @m12.match?("abb")
    assert @m12.match?("ab ")
    assert @m12.match?("y")
    assert @m12.match?("xyz")
    assert @m12.match?(" yz")
    assert @m12.match?("yz ")
  end
end