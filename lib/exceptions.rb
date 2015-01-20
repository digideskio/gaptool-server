class HTTPError < StandardError
  @code = 500

  def self.code
    @code
  end

 def code
    self.class.code
 end
end

class ClientError < HTTPError
  @code = 400
end

class BadRequest < ClientError
  @code = 400
end

class Forbidden < ClientError
  @code = 403
end

class NotFound < ClientError
  @code = 404
end

class Conflict < ClientError
  @code = 409
end
