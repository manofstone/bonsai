# jms mod, to use pry
require 'irb'
module Bonsai
  class Console
    def initialize
      silence_warnings do
        begin
          require 'pry'
          IRB = Pry
        rescue LoadError
        end
      end
      IRB.start(__FILE__)
    end
  end
end