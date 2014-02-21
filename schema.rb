module RubySchema
	module_function

	class AllSpec < Struct.new(:specs)
		def === other
			specs.all? {|spec| spec === other}
		end
	end

	def all_of(*specs)
		AllSpec.new specs
	end

	class AnySpec < Struct.new(:specs)
		def === other
			specs.any? {|spec| spec === other}
		end
	end

	def any_of(*specs)
		AnySpec.new specs
	end

	class ArraySpec < Struct.new(:spec)
		def === other
			other.is_a? Array and
				other.all? {|e| spec === e}
		end
	end

	def array_of(spec)
		ArraySpec.new spec
	end

	class TupleSpec < Struct.new(:specs)
		def === other
			other.is_a? Array and
				other.length == specs.length and
				other.zip(specs).all? {|e, spec| spec === e}
		end
	end

	def tuple(*specs)
		TupleSpec.new specs
	end

	class HashSpec < Struct.new(:specs, :exclusive)
		def === other
			other.is_a? Hash and
				(!exclusive or specs.keys & other.keys == specs.keys) and
				specs.all? {|k, v| v === other[k]}
		end
	end

	def hash(exclusive=false, specs)
		HashSpec.new specs, exclusive
	end

	class MethodsSpec < Struct.new(:specs)
		def === other
				specs.all? {|k, v| other.respond_to? k and v === other.send(k)}
		end
	end

	def methods(specs)
		MethodsSpec.new specs
	end
end

def schema(&blk)
	RubySchema.instance_eval &blk
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

