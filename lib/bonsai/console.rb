jms mod, to use pry
# require 'irb'
require 'pry'
module Bonsai
  class Console
    def initialize
      # IRB.start(__FILE__)
      PRY.start(__FILE__)
    end
  end
end