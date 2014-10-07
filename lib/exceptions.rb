class HTTPError < StandardError
  @@code = 500

  def code
    @@code
  end
end

class BadRequest < HTTPError
  @@code = 400
end
