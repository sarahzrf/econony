require_relative 'schema'

module BlockchainSchemas
	str = proc {|len| schema {all_of(String, methods(length: len))}}
	hex = proc {|s| s.chars.all? {|char| char =~ /[0-9a-f]/}}
	SHA1 = schema {all_of(str[40], hex)}
	Input = schema {tuple(SHA1, Fixnum)}
	Output = schema {tuple(SHA1, Rational)}
	Signature = schema {
		all_of(
			Signature,
			methods(signed_hash: str[256], pubkey: str[451])
		)
	}
	Transaction = schema {
		methods(
			inputs: array_of(Input),
			outputs: array_of(Output),
			timestamp: Fixnum,
			signature: any_of(Signature, nil)
		)
	}
	Block = schema {
		methods(
			txns: array_of(Transaction),
			prev: SHA1,
			timestamp: Fixnum,
			nonce: Fixnum,
			index: Fixnum
		)
	}
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

