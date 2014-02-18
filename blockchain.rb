require 'digest/sha1'

# the blockchain will be stored as a hash
# of id => block

module Blockchain
	InitialDifficulty = 5_000_000_000_000_000

	def self.difficulty
		years = Date.today.year - 2014
		p2 = 2**years
		InitialDifficulty * p2
	end

	def self.block(id)
		(@chain ||= {})[id]
	end

	class Block
		attr_reader :txns, :prev, :timestamp, :nonce

		def initialize(txns, prev, timestamp, nonce)
			@txns, @prev, @timestamp, @nonce = txns, prev, timestamp, nonce
		end

		def id
			Digest::SHA1.hexdigest(
				nonce + prev + timestamp + txns.join)
		end

		def valid?
			id.hex < Blockchain.difficulty
		end

		def to_s
			"#<Block 0x#{id}>"
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

