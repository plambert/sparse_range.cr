# Additional utility methods for `Range` instances

struct Range(B, E)
  include Comparable(Range(B, E))

  def to_json(json : JSON::Builder)
    [self.begin, self.end, exclusive?].to_json(json)
  end

  def overlaps?(other) : Bool
    raise ArgumentError.new "cannot check overlap of exclusive ranges" if self.exclusive? || other.exclusive?

    # If either range includes either the begin or end of the other, they overlap
    return true if (other.begin && self.includes? other.begin) ||
                   (other.end && self.includes? other.end) ||
                   (self.begin && other.includes? self.begin) ||
                   (self.end && other.includes? self.end)

    # If both ranges are nil..nil then they overlap
    return true if self.begin.nil? && self.end.nil? && other.begin.nil? && other.end.nil?

    false
  end

  # Check to see if one range abuts the other; this requires that the types involved
  # respond to `#pred` and `#succ`.
  def abuts?(other) : Bool
    raise ArgumentError.new "cannot check abut of exclusive ranges" if self.exclusive? || other.exclusive?

    return true if (self.end && other.begin && other.begin == self.end.succ) ||
                   (self.begin && other.end && other.end == self.begin.pred)

    false
  end

  # Check to see if the other range overlaps abuts this one
  def overlaps_or_abuts?(other) : Bool
    overlaps?(other) || abuts?(other)
  end

  # If the other range overlaps or abuts this one, return a merged range, otherwise
  # return nil
  def merge?(other) : self?
    if overlaps?(other) || abuts?(other)
      Range(B, E).new Math.min(self.begin, other.begin), Math.max(self.end, other.end)
    else
      nil
    end
  end

  # If the other range overlaps or abuts this one, return a merged range, otherwise
  # return this one unchanged
  def merge(other) : self
    merge?(other) || self
  end

  # If the other range overlaps or abuts this one, return a merged range, otherwise
  # raise an error
  def merge!(other) : self
    merge?(other) || raise "Cannot merge #{self} with #{other}: they do not overlap or abut"
  end

  def <=>(other : Range(B, E))
    chain_compare compare_with_nils(self.begin, other.begin), compare_with_nils(self.end, other.end)
  end

  private def chain_compare(*values)
    values.each do |val|
      return val unless val == 0
    end
    0
  end

  private def compare_with_nils(a, b)
    if a && b
      a <=> b
    elsif a.nil? && b.nil?
      0
    elsif a.nil?
      -1
    else
      1
    end
  end
end
