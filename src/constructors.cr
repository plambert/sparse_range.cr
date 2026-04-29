require "./sparse_range"

class SparseRange(T)
  {% begin %}
    {% for inttype in [Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128] %}
  def self.new(klass : {{inttype.id}}.class, *args)
    SparseRange({{inttype.id}}).new(*args)
  end
    {% end %}
  {% end %}
end
