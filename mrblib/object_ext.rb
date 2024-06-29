class Object
  def to_json(opts = {})
    JSON.generate(self, opts)
  end
end
