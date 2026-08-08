require "./sparse_range"

class SparseRange(T)
  {% begin %}
    {% for inttype in [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128] %}
      # Creates a `SparseRange({{ inttype.id }})`, forwarding every argument to
      # `SparseRange({{ inttype.id }})#initialize`.
      #
      # ```
      # SparseRange.new({{ inttype.id }}, list: "1..5,7")
      # ```
      #
      # NOTE: the class argument decides the element type, so
      # `SparseRange(Int64).new({{ inttype.id }})` returns a
      # `SparseRange({{ inttype.id }})`.
      def self.new(klass : {{ inttype.id }}.class, *args, **options)
        SparseRange({{ inttype.id }}).new(*args, **options)
      end
    {% end %}
  {% end %}
end
