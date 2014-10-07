class HTTPError < StandardError
  @code = 500

  def self.code
    @code
  end

 def code
   self.class.code
 end
end

class BadRequest < HTTPError
  @code = 400
end

class Unauthenticated < BadRequest
  @code = 401
end
