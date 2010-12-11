$: << File.join(File.dirname(File.expand_path(__FILE__)), "..", "lib")
require 'test/unit'
require "nfa"

class FSATest < Test::Unit::TestCase
  def test_nfa
    # create some states with which to manually construct an NFA
    start = FSA::State.new
    a = FSA::State.new
    b1 = FSA::State.new
    b2 = FSA::State.new
    c = FSA::State.new(true)
  
    # build an NFA to match "abbc"
    nfa = FSA::NFA.new(start)
    nfa.add_transition('a', start, a)
    nfa.add_transition('b', a, b1)
    nfa.add_transition('b', b1, b2)
    nfa.add_transition('c', b2, c)
  
    # run the NFA
    assert !nfa.match?("abc")
    assert !nfa.match?("")
    assert !nfa.match?("abbcc")
    assert nfa.match?("abbc")

    # build an NFA to match "abbc"
    nfa = FSA::NFA.new(start)
    nfa.add_transition('a', start, a)
    nfa.add_transition('b', a, b1)
    nfa.add_transition(:epsilon, a, b1)
    nfa.add_transition('b', b1, b2)
    nfa.add_transition('c', b2, c)
  
    # run the NFA
    assert nfa.match?("abc")
    assert !nfa.match?("")
    assert !nfa.match?("abbcc")
    assert nfa.match?("abbc")
  end
end