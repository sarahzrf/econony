require_relative 'schema'

module BlockchainSchemas
	SHA1 = schema {all_of(String, methods(length: 40))}
	Input = schema {tuple(SHA1, Fixnum)}
	Output = schema {tuple(SHA1, Rational)}
	Signature = schema {
		all_of(
			Signature,
			methods(signed_hash: String, pubkey: String)
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

