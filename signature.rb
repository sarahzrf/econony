require 'openssl'

class Signature
	attr_reader :signed_hash, :pubkey

	def self.signature_for(thing, privkey)
		if thing.is_a? Numeric
			hash = thing.to_s(16)
		else
			hash = thing.hash
		end
		key = OpenSSL::PKey::RSA.new privkey
		signed_hash = key.private_encrypt hash
		Signature.new signed_hash, key.public_key.to_s
	end

	def initialize(signed_hash, pubkey)
		@signed_hash, @pubkey = signed_hash, pubkey
	end

	def signs?(thing)
		case thing
		when String
			hash = thing
		when Numeric
			hash = thing.to_s(16)
		else
			hash = thing.hash
		end
		begin
			key = OpenSSL::PKey::RSA.new @pubkey
			key.public_decrypt(@signed_hash) == hash
		rescue OpenSSL::PKey::RSAError
			false
		end
	end
end

module Signable
	attr_reader :signature

	def sign(privkey)
		@signature = Signature.signature_for self, privkey
	end

	def signed?
		return false unless signature
		signature.signs? self
	end

	def pubkey
		return nil unless signature
		signature.pubkey
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

