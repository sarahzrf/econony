require 'digest/sha1'

# the blockchain will be stored as a hash
# of id => block

module Blockchain
	InitialDifficulty = 10**41
	Difficulty = InitialDifficulty / 2**(Date.today.year - 2014)

	def self.block(id)
		(@chain ||= {})[id]
	end

	class Block
		attr_reader :txns, :prev, :timestamp, :nonce

		def initialize(txns, prev, timestamp, nonce)
			@txns = txns
			@prev = prev
			@timestamp = timestamp.to_i
			@nonce = nonce
		end

		def hash
			@hash ||= Digest::SHA1.hexdigest(
				nonce.to_s << prev << timestamp.to_s <<
				txns.map(&:hash).inject('', :<<)).hex
		end

		def valid?
			hash < Blockchain::Difficulty
		end

		def inspect
			"#<Block 0x#{hash.to_s 16}>"
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

