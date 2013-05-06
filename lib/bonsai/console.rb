# jms mod, to use pry
require 'irb'
require 'pry'
module Bonsai
  class Console
    def initialize
      Pry.start(__FILE__)
    end
  end
end