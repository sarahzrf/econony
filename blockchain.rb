require_relative 'sha1'
require_relative 'signature'

# the blockchain will be stored as a hash
# of id => block

module Blockchain
	InitialDifficulty = 10**40 * 5
	Difficulty = InitialDifficulty / 2**(Date.today.year - 2014)

	def self.block(id)
		(@chain ||= {})[id]
	end

	class Block
		include Signable

		attr_reader :txns, :prev, :timestamp, :nonce

		def initialize(txns, prev, timestamp, nonce)
			@txns = txns
			@prev = prev
			@timestamp = timestamp.to_i
			@nonce = nonce
		end

		def hash
			@hash ||= (nonce.to_s << prev.to_s <<
								 timestamp.to_s <<
								 txns.map(&:hash).inject('', :<<)).sha1
		end

		def valid?
			@valid ||= hash.hex < Blockchain::Difficulty
		end

		def inspect
			@inspect ||= "#<Block 0x#{hash}>"
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

